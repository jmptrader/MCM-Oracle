#!/usr/bin/env perl

use strict;

use Mx::Config;
use Mx::Log;
use Mx::Error;
use Mx::Alert;
use Mx::Secondary;
use Mx::Oracle;
use Mx::DBaudit;
use Mx::Semaphore;
use Mx::Scheduler;
use Mx::Process;
use BerkeleyDB;
use Perl::Unsafe::Signals;
use Getopt::Long;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: remote.pl [ -i <instance> ] [ -c <command> ] [ -t <timeout> ] [ -force_ok ] [ -nowait] [ -cleanup ] [ -bg ] [ -help ]
 
 -i <instance>        Instance number of the application server.
 -c <command>         Remote command that must be executed.
 -t <timeout>         Timeout in seconds (e.g. 300) or wall clock time (e.g. 23:00:00). No timeout if unspecified.
 -force_ok            Return success when a timout occurs (to fool TWS).
 -nowait              Do not delay the job when Sybase is overloaded.
 -cleanup             Cleanup the remote map.
 -bg                  Launch command in the background.
 -help                Display this text.
 
EOT
;
    exit 1;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";
 
#
# process the commandline arguments
#
my ($instance, $command, $timeout, $nowait, $force_ok, $cleanup, $background);
 
GetOptions(
    'i=s'        => \$instance,
    'c=s'        => \$command,
    't=s'        => \$timeout,
    'nowait!'    => \$nowait,
    'force_ok!'  => \$force_ok,
    'cleanup!'   => \$cleanup,
    'bg!'        => \$background,
    'help'       => \&usage,
);

$timeout = 0;

unless ( $command or $cleanup ) {
    usage();
}

my ( $sched_js ) = $command =~ /-sched_js\s+(\w+)\b/;
my ( $project )  = $command =~ /-project\s+(\w+)\b/;

unless ( $project ) {
    ( $project ) = $command =~ /\/kbc\/(\w+)\/bin\//;
}

#
# read the configuration files
#
my $config = Mx::Config->new();

my $bdb_dir = $config->RUNDIR;

$config->set_project_variables( $project ) if $project;

#
# initialize logging
#
my $keyword = ( $sched_js ) ? $sched_js : 'remote';
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => $keyword );

$logger->info("remote.pl $args");

if ( $sched_js ) {
    if ( my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config ) ) {
        exit 0 if $scheduler->is_disabled;
    }
}

my $remote_map       = $config->REMOTE_MAP;
my $lock_timeout     = $config->REMOTE_MAP_LOCK_TIMEOUT;
my $remote_delay     = $config->REMOTE_DELAY;
my $remote_max_delay = $config->REMOTE_MAX_DELAY;

my $start_time = time();

if ( $timeout ) {
    if ( $timeout =~ /^\d+$/ ) {
        $logger->info("timeout of $timeout seconds specified");
    }
    elsif ( $timeout =~ /^(\d\d?):(\d\d):(\d\d)$/ ) {
        $logger->info("timeout specified as $timeout");

        my $limit = $1 * 3600 + $2 * 60 + $3;
        my ( $sec, $min, $hour ) = localtime();
        my $current = $hour * 3600 + $min * 60 + $sec;
        $timeout = $limit - $current;
        $timeout += 86400 if $timeout < 0;

        $logger->info("converted to a timeout of $timeout seconds");
    }
    else {
        $logger->logdie("wrong timeout value ($timeout) specified");
    }
}

if ( $cleanup ) {
    unless ( -f $remote_map ) {
        $logger->warn("no remote map found ($remote_map)");
        exit 0;
    }

    if ( unlink $remote_map ) {
        $logger->info("remote map cleaned up");
        exit 0;
    }
    else {
        $logger->logdie("failed to cleanup remote map: $!");
    }
}

if ( defined( $instance ) && $instance !~ /^\d+$/ ) {
    $logger->logdie("invalid instance number: $instance\n");
}

unless ( $nowait ) {
    my $semaphore = Mx::Semaphore->new( key => 'remote', type => $Mx::Semaphore::TYPE_TIME, create => 1, logger => $logger, config => $config );

    if ( $semaphore->acquire( no_fail => 1 ) ) {
        $semaphore->release( delay => $remote_delay, max_own_delay => $remote_max_delay );

        $logger->debug("remote delay is OK");
    }
}

unless ( $nowait || 1 ) {
    my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

    my ( $io_resource ) = $db_audit->retrieve_resources( name => $config->DSQUERY );

    my $nowait_flag;
    if ( $sched_js && $project ) {
        $nowait_flag = $config->PROJECT_RUNDIR . '/' . $sched_js . '.nowait';
    }

    while ( $io_resource->{value} <= 0 ) {
        if ( $nowait_flag && -f $nowait_flag ) {
            $logger->info("nowait flag detected ($nowait_flag), ignoring I/O resource pool");
            unlink $nowait_flag;
            $nowait = 1;
            last;
        }

        $logger->warn('I/O resource pool is empty (' . $io_resource->{value} . '), going to sleep for 1 minute');
        sleep 60;
        ( $io_resource ) = $db_audit->retrieve_resources( name => $config->DSQUERY );
    }

    $logger->info('I/O resource pool is ok (' . $io_resource->{value} . ')') unless $nowait;

    $db_audit->close();
}


Mx::Secondary->init( logger => $logger, config => $config );

my $handle;
if ( defined( $instance ) ) {
        my $nr_instances = Mx::Secondary->nr_instances();

        $instance = ( $instance >= $nr_instances ) ? $nr_instances - 1 : $instance;

        $handle = Mx::Secondary->handle( instance => $instance, config => $config, logger => $logger );
}
else {
    my %jobstreams;
    if ( $sched_js ) {
        unless ( -f $remote_map ) {
            $logger->warn("remote map $remote_map does not exist, an empty one will be created");
        }

        $logger->debug("initializing BerkeleyDB environment");
 
        $SIG{ALRM} = \&lock_handler;

        alarm( $lock_timeout );

        UNSAFE_SIGNALS {
            my $env;
            unless ( $env = BerkeleyDB::Env->new(
              -Home       => $bdb_dir,
              -ErrFile    => "$bdb_dir/BerkeleyDB_errors.log",
              -Flags      => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL,
              -LockDetect => DB_LOCK_DEFAULT
            ) ) {
                $logger->logdie("cannot open BerkeleyDB environment: $BerkeleyDB::Error");
            }

            $logger->debug("BerkeleyDB environment initialized, opening remote map $remote_map"); 

            unless ( tie %jobstreams, 'BerkeleyDB::Hash', -Filename => $remote_map, -Flags => DB_CREATE, -Env => $env ) {
                $logger->logdie("cannot open $remote_map: $! $BerkeleyDB::Error");
            }
        };

        alarm( 0 );

        if ( my $instance = $jobstreams{ $sched_js } ) {
            $handle = Mx::Secondary->handle( instance => $instance, config => $config, logger => $logger );
            $logger->debug("jobstream $sched_js already connected to app server $instance");
            untie %jobstreams;
        }
        else {
            $logger->debug("jobstream $sched_js not yet connected to a app server");
        }
    }

    unless ( $handle ) {
        my @handles = Mx::Secondary->handles( config => $config, logger => $logger );
       
        my $min_avg_load = 9999;
        while ( my $thandle = shift @handles ) {
            my $instance = $thandle->instance;
            my $handicap = $thandle->batch_handicap;

            my $avg_load;
            eval { $avg_load = $thandle->soaphandle->avg_load()->result; };

            if ( $@ ) {
                $logger->error("app server $instance is not answering, skipping");
                next;
            }

            $logger->info("average load app server $instance: $avg_load + $handicap");

            $avg_load += $handicap;

            if ( $avg_load < $min_avg_load ) {
                $handle->close if $handle;

                $min_avg_load = $avg_load;

                $handle = $thandle;
            }
            else {
                $thandle->close;
            }
        }

        unless ( $handle ) {
            $logger->logdie("no usable app server found");
        }

        $instance = $handle->instance;

        if ( $sched_js ) {
            $jobstreams{ $sched_js } = $instance;
            untie %jobstreams;
        }

        $logger->info("opting for app server $instance");
    }
}

my $remote_delay = time() - $start_time;
$logger->debug("total remote delay is $remote_delay seconds");

if ( $command =~ /batch\.pl / ) {
    $command .= " -remote_delay $remote_delay";
}

my ( $success, $error_message, $output, $pid, $key );

eval {
    if ( $background ) {
        $key = $handle->run_async( command => $command, timeout => $timeout, mxweblog => $ENV{MXWEBLOG} );
    }
    else { 
        ( $success, $error_message, $output, $pid ) = $handle->run( command => $command, timeout => $timeout, mxweblog => $ENV{MXWEBLOG} );
    }
};

if ( $@ ) {
    print "remote command execution failed: $@\n";
    $logger->error("remote command execution failed: $@");
    exit 1;
}

if ( $background ) {
    print "instance: $instance key: $key\n";
    exit 0;
}

print $output;

if ( $error_message =~ /IPC::Cmd::TimeOut/ ) {
    $logger->error("timeout received (value is $timeout seconds)");

    my $alert = Mx::Alert->new( name => 'command_timeout', config => $config, logger => $logger );
    $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $command, $timeout ] );

    if ( $force_ok ) {
        $logger->warn("returncode forced to 0");
        exit 0;
    }

    exit $Mx::Error::COMMAND_TIMEOUT;
}

unless ( $success ) {
    $logger->logdie("remote command execution failed");
}

exit 0;

sub lock_handler {
    my $alert = Mx::Alert->new( name => 'remote_map_locked', config => $config, logger => $logger );
    $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $command, $lock_timeout ], item => $remote_map );
}
