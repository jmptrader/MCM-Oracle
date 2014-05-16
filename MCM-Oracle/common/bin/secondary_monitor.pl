#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Util;
use POSIX;
use SOAP::Transport::HTTP;
use Mx::Secondary;
use Mx::Collector;
use Getopt::Long;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: secondary_monitor.pl [ -start ] [ -stop ] [ -stopall ] [ -restart ] [ -restartall ] [ -list_shares ] [ -cleanup_shares ] [ -help ]
 
 -start            Start the monitor on this server.
 -stop             Stop the monitor on this server.
 -stopall          Stop all monitors.
 -restart          Restart the monitor on this server.
 -restartall       Restart all monitors.
 -list_shares      List all registered shared memory segments.
 -cleanup_shares   Remove all registered expired shared memory segments.
 -help             Display this text.
 
EOT
;
    exit;
}
 
my ($do_start, $do_stop, $do_stopall, $do_restart, $do_restartall, $list_shares, $cleanup_shares );
 
GetOptions(
    'start'           => \$do_start,
    'stop'            => \$do_stop,
    'stopall'         => \$do_stopall,
    'restart'         => \$do_restart,
    'restartall'      => \$do_restartall,
    'list_shares'     => \$list_shares,
    'cleanup_shares'  => \$cleanup_shares,
    'help'            => \&usage,
);


# read the configuration files
#
my $config = Mx::Config->new();

my $hostname = Mx::Util->hostname();

#
# initialize logging
#
my $logger = Mx::Log->new(directory => $config->LOGDIR, keyword => "secondary_monitor_$hostname");

if ( $do_stop  or $do_restart ) {
    $logger->info("stopping the secondary monitor");

    my $pidfile  = Mx::Process->pidfile( descriptor => "secondary_monitor_$hostname", config => $config );

    if ( ! -f $pidfile ) {
        $logger->info("pidfile $pidfile not found, secondary monitor not running");
    }
    elsif ( my $process = Mx::Process->new( pidfile => $pidfile, config => $config, logger => $logger ) ) {
        if ( $process->kill ) {
            $logger->info("secondary monitor killed");
            $process->remove_pidfile();
        }
        else {
            $logger->error("secondary monitor cannot be killed");
        }
    }
    else {
        $logger->warn("pidfile $pidfile present, but no process running");
        unlink( $pidfile );
    }
}

if ( $do_stopall ) {
    $logger->info("stopping all secondary monitors");

    my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

    my $rc = 0;
    foreach my $handle ( @handles ) {
        my ( $success ) = $handle->stop;
        $rc = 1 unless $success;
    }

    exit $rc;
}

if ( $do_restartall ) {
    $logger->info("restarting all secondary monitors");

    my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

    my $rc = 0;
    foreach my $handle ( @handles ) {
        my ( $success ) = $handle->restart;
        $rc = 1 unless $success;
    }

    exit $rc;
}

if ( $list_shares ) {
    my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

    foreach my $handle ( @handles ) {
        printf "Instance %d (%s):\n", $handle->instance, $handle->hostname;
 
        my %shares = $handle->soaphandle->list_shares()->paramsall;
        while ( my ($key, $expiry ) = each %shares ) {
            printf "  key: %10s   expiry: %20s\n", $key, scalar(localtime($expiry));
        }
    }
}

if ( $cleanup_shares ) {
    my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

    foreach my $handle ( @handles ) {
        printf "Instance %d (%s): ", $handle->instance, $handle->hostname;

        my $nr_shares = $handle->soaphandle->cleanup_shares()->paramsall;

        printf "$nr_shares shares cleaned up\n";
    }
}

if ( $do_start or $do_restart ) {
    my $hostname    = Mx::Util->hostname();
    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
    my $portnumber  = $config->SECONDARY_MON_PORT;

    my $instance = 0; my $ok = 0;
    foreach my $app_server ( @app_servers ) {
        if ( $hostname eq Mx::Util->hostname( $app_server ) ) {
            $logger->info("starting secondary monitor on $hostname (instance: $instance)");
            $ok = 1;
            last;
        } 

        $instance++;
    }

    unless ( $ok ) {
        $logger->logdie("secondary monitor is not allowed to start on $hostname (instance $instance)");
    }

    #
    # become a daemon
    #
    my $pid = fork();
    exit if $pid;
    unless ( defined($pid) ) {
        $logger->logdie("cannot fork: $!");
    }

    unless ( setsid() ) {
        $logger->logdie("cannot start a new session: $!");
    }

    close(STDIN);

    my $process = Mx::Process->new( descriptor => 'secondary_monitor', logger => $logger, config => $config, light => 1 );
    unless ( $process->set_pidfile( $0, "secondary_monitor_$hostname" ) ) {
        $logger->logdie("not running exclusively");
    }

    my $logfile = $logger->filename;
    open STDOUT, ">>$logfile";
    open STDERR, ">>$logfile";

    $SIG{CHLD} = 'IGNORE';

    my $daemon = SOAP::Transport::HTTP::Daemon::ForkOnAccept
        -> new( LocalPort => $portnumber, Reuse => 1, Listen => 50 )
        -> dispatch_to( 'Mx::Secondary' );

    $logger->info("secondary monitor listening on $hostname:$portnumber");

    Mx::Secondary->init( config => $config, logger => $logger, instance => $instance );

    Mx::Secondary->services();

    Mx::Collector->init_disabled_collectors( config => $config );

    Mx::Secondary->collectors();

    $daemon->handle;
}
