#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Util;
use Mx::DBaudit;
use Mx::Job;
use POSIX;
use Getopt::Long;

my %WAITING_JOBS   = ();
my @READY_JOBS     = ();
my %RUNNING_JOBS   = ();
my @COMPLETED_JOBS = ();
my %EXITED_JOBS    = ();

my $RUNNING_SLEEP  = 5;    # sleep interval used when there are running jobs
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: jobscheduler.pl [ -start ] [ -stop ] [ -restart ] [ -help ]
 
 -start    Start the job scheduler.
 -stop     Stop the job scheduler.
 -restart  Restart the job scheduler.
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


# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new(directory => $config->LOGDIR, keyword => 'jobscheduler');

if ( $do_stop  or $do_restart ) {
    $logger->info("stopping the job scheduler");

    my $pidfile  = Mx::Process->pidfile( descriptor => "jobscheduler", config => $config );

    if ( ! -f $pidfile ) {
        $logger->info("pidfile $pidfile not found, job scheduler not running");
    }
    elsif ( my $process = Mx::Process->new( pidfile => $pidfile, config => $config, logger => $logger ) ) {
        if ( $process->kill ) {
            $logger->info("job scheduler killed");
            $process->remove_pidfile();
        }
        else {
            $logger->error("job scheduler cannot be killed");
        }
    }
    else {
        $logger->warn("pidfile $pidfile present, but no process running");
        unlink( $pidfile );
    }
}

if ( $do_start or $do_restart ) {
    my $hostname    = Mx::Util->hostname();
    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );

    unless ( $hostname eq Mx::Util->hostname( $app_servers[0] ) ) {
        $logger->logdie("job scheduler is not allowed to start on $hostname");
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

    my $process = Mx::Process->new( descriptor => 'jobscheduler', logger => $logger, config => $config, light => 1 );
    unless ( $process->set_pidfile( $0, 'jobscheduler' ) ) {
        $logger->logdie("not running exclusively");
    }

    my $logfile = $logger->filename;
    open STDOUT, ">>$logfile";
    open STDERR, ">>$logfile";

    my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

    my @jobs = Mx::Job->retrieve_all( config => $config, logger => $logger );

    foreach my $job ( @jobs ) {
        my $next_runtime  = $job->schedule( db_audit => $db_audit );

        while ( exists $WAITING_JOBS{$next_runtime} ) {
            $next_runtime++;
        }

        $WAITING_JOBS{$next_runtime} = $job;
    }

    $SIG{CHLD} = \&reaper;

    #############
    #           #
    # MAIN LOOP #
    #           #
    #############
    while ( %WAITING_JOBS or @READY_JOBS or %RUNNING_JOBS or @COMPLETED_JOBS ) {
        my $current_time = time();
        my $sleeptime = $RUNNING_SLEEP;

        #
        # WAITING JOBS -> READY JOBS
        #
        foreach my $next_runtime ( sort { $a <=> $b } keys %WAITING_JOBS ) {
            $sleeptime = $next_runtime - $current_time;

            last if $sleeptime > 0;

            my $job = $WAITING_JOBS{$next_runtime};
            delete $WAITING_JOBS{$next_runtime};

            $job->set_ready( db_audit => $db_audit );

            push @READY_JOBS, $job;
        }

        my $nr_waiting_jobs = keys %WAITING_JOBS;

        $logger->debug("number of waiting jobs: $nr_waiting_jobs");

        unless ( $nr_waiting_jobs ) {
            $sleeptime = $RUNNING_SLEEP;
        }

        #
        # READY JOBS -> RUNNING JOBS
        #
        while ( my $job = shift @READY_JOBS ) {
            my $pid = $job->run( db_audit => $db_audit );

            $RUNNING_JOBS{$pid} = $job if $pid;
        }

        #
        # RUNNING JOBS -> COMPLETED JOBS: normally via signal handler
        #
        while ( my ( $pid, $ref ) = each %EXITED_JOBS ) {
            my $job = $RUNNING_JOBS{$pid};

            unless ( $job ) {
                $logger->error("a child process with pid $pid has exited which is not registered as running job");
                delete $EXITED_JOBS{$pid};
                next;
            }

            $job->set_exittime( $ref->{exittime} );
            $job->set_exitcode( $ref->{exitcode} );

            delete $EXITED_JOBS{$pid};
            delete $RUNNING_JOBS{$pid};

            push @COMPLETED_JOBS, $job;
        }

        my $nr_running_jobs = keys %RUNNING_JOBS;

        $logger->debug("number of running jobs: $nr_running_jobs");

        if ( $nr_running_jobs ) {
            $sleeptime = ( $sleeptime < $RUNNING_SLEEP ) ? $sleeptime : $RUNNING_SLEEP;
        }

        #
        # COMPLETED JOBS -> WAITING JOBS
        #
        while ( my $job = shift @COMPLETED_JOBS ) {
            my $reschedule = $job->complete( db_audit => $db_audit );

            next unless $reschedule;

            my $next_runtime = $job->schedule( db_audit => $db_audit );

            while ( exists $WAITING_JOBS{$next_runtime} ) {
                $next_runtime++;
            }

            $WAITING_JOBS{$next_runtime} = $job;

            my $new_sleeptime = $next_runtime - time();

            $sleeptime = ( $new_sleeptime < $sleeptime ) ? $new_sleeptime : $sleeptime;
        }

        if ( $sleeptime > 0 ) {
            $logger->debug("going to sleep for $sleeptime seconds");

            sleep $sleeptime;
        }
    }

    $logger->info("no more jobs to handle, jobscheduler exiting");
}

#----------#
sub reaper {
#----------#
    my $pid;

    while ( ( $pid = waitpid( -1, &WNOHANG ) ) > 0 ) {
        my $exittime = time();
        my $exitcode = $? >> 8;

        my $job = $RUNNING_JOBS{$pid};

        if ( $job ) {
            $job->set_exittime( $exittime );
            $job->set_exitcode( $exitcode );

            delete $RUNNING_JOBS{$pid};

            push @COMPLETED_JOBS, $job;
        }
        else {
            $EXITED_JOBS{$pid} = { exittime => $exittime, exitcode => $exitcode };
        }
    }

    $SIG{CHLD} = \&reaper;
}

