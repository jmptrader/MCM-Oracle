#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Auth::DB;
use Mx::Auth::Replicator;
use Mx::Util;
use POSIX;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: auth_replicator.pl [ -start ] [ -stop ] [ -restart ] [ -help ]
 
 -start    Start the replicator.
 -stop     Stop the replicator.
 -restart  Restart the replicator.
 -help     Display this text.
 
EOT
;
    exit;
}
 
my ($do_start, $do_stop, $do_restart);
 
GetOptions(
    'start'   => \$do_start,
    'stop'    => \$do_stop,
    'restart' => \$do_restart,
    'help'    => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new(directory => $config->LOGDIR, keyword => 'auth_replicator');

if ( $do_stop or $do_restart ) {
    $logger->info("stopping the replicator");

    my $pidfile  = Mx::Process->pidfile( descriptor => "auth_replicator", config => $config );

    if ( ! -f $pidfile ) {
        $logger->info("pidfile $pidfile not found, replicator not running");
    }
    elsif ( my $process = Mx::Process->new( pidfile => $pidfile, config => $config, logger => $logger ) ) {
        if ( $process->kill ) {
            $logger->info("replicator killed");
            $process->remove_pidfile();
        }
        else {
            $logger->error("replicator cannot be killed");
        }
    }
    else {
        $logger->warn("pidfile $pidfile present, but no process running");
        unlink( $pidfile );
    }
}

if ( $do_start or $do_restart ) {
    my $environment     = $config->MXENV;
    my $replicator_type = $config->AUTH_REPLICATOR_TYPE;

    my $master;

    if ( $replicator_type eq $Mx::Auth::Replicator::TYPE_MASTER ) {
        $master = 1;
        my $message = "replicator started as master";
        $logger->info($message);
        print "$message\n";
    }
    elsif ( $replicator_type eq $Mx::Auth::Replicator::TYPE_SLAVE ) {
        $master = 0;
        my $message = "replicator started as slave";
        $logger->info($message);
        print "$message\n";
    }
    else {
        my $message = "$environment is not configured to run a master or slave replicator";
        $logger->error($message);
        print "$message\n";
        exit 1;
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

    my $process = Mx::Process->new( descriptor => 'auth_replicator', logger => $logger, config => $config, light => 1 );
    unless ( $process->set_pidfile( $0, 'auth_replicator' ) ) {
        $logger->logdie("not running exclusively");
    }

    my $logfile = $logger->filename;
    open STDOUT, ">>$logfile";
    open STDERR, ">>$logfile";

    my $auth_db = Mx::Auth::DB->new( logger => $logger, config => $config );

    if ( $master ) {
        my @replicators = Mx::Auth::Replicator->retrieve_all( db => $auth_db, config => $config, logger => $logger );

        @replicators = sort { $a->peer_nr <=> $b->peer_nr } @replicators;

        my ( $lowest_replication_id ) = sort { $a <=> $b } map { $_->replication_id } @replicators;

        $logger->info("lowest replication id: $lowest_replication_id");

        my $sync_interval = $Mx::Auth::Replicator::SYNC_INTERVAL;

        $logger->info("sync interval is $sync_interval seconds");

        while ( 1 ) {
            my $max_replication_id = $auth_db->max_replication_id;

            if  ( $max_replication_id > $lowest_replication_id ) {
                foreach my $replicator ( @replicators ) {
                    if ( ! $replicator->disabled && ! $replicator->in_sync( replication_id => $max_replication_id ) ) {
                        $replicator->sync;
                    }
                }
            }

            ( $lowest_replication_id ) = sort { $a <=> $b } map { $_->replication_id } @replicators;

            $logger->info("lowest replication id: $lowest_replication_id");

            sleep $sync_interval;
        }
    } 
    else {
        my $replicator = Mx::Auth::Replicator->new( name => $environment, db => $auth_db, config => $config, logger => $logger );

        my $required_hostname = $replicator->hostname;
        my $actual_hostname   = Mx::Util->hostname;
        $required_hostname =~ s/^([^.]+).*$/$1/; 

        if ( $required_hostname ne $actual_hostname ) {
            my $message = "expect to be started on $required_hostname, not on $actual_hostname ";
            $logger->error($message);
            print "$message\n";
            exit 1;
        }

        $replicator->listen;
    }
}

