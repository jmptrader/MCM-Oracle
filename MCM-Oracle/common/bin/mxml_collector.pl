#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::MxML::Node;
use Mx::MxML::Task;
use Mx::MxML::Threshold;
use Mx::Logfile;
use Mx::Account;
use Mx::Oracle;
use Mx::DBaudit;
use Mx::SQLLibrary;
use Mx::Alert;
use Mx::Ant;
use POSIX;

my $name = 'mxml';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $poll_interval = $collector->poll_interval;

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

#
# create a pidfile
#
my $process = Mx::Process->new( descriptor => $descriptor, logger => $logger, config => $config, light => 1 );
unless ( $process->set_pidfile( $0, $pidfile ) ) {
    $logger->logdie("not running exclusively");
}

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );
 
#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
 
#
# initialize the database connection
#
my $oracle  = Mx::Oracle->new( database => $config->DB_FIN, username => $account->name, password => $account->password, logger => $logger, config => $config );
 
#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
 
#
# open the database connection
#
$oracle->open();

my $size_alert       = Mx::Alert->new( name => 'mxml_queue_size',    config => $config, logger => $logger );
my $timeout_alert    = Mx::Alert->new( name => 'mxml_queue_timeout', config => $config, logger => $logger );
my $throughput_alert = Mx::Alert->new( name => 'mxml_throughput',    config => $config, logger => $logger );
my $import_alert     = Mx::Alert->new( name => 'mxml_import',        config => $config, logger => $logger );

my ( $nodes_ref, $tasks_ref ) = Mx::MxML::Node->retrieve_all( logger => $logger, config => $config, db_audit => $db_audit, exclude => 1 );
my @thresholds = Mx::MxML::Threshold->retrieve_all( logger => $logger, config => $config );
my $throughput_threshold = Mx::MxML::Threshold->message_throughput( logger => $logger, config => $config );

Mx::MxML::Task->apply_thresholds( tasks => $tasks_ref, thresholds => \@thresholds, logger => $logger );

my @task_directories = (); my $task_directory_index = 0; my $mxenv_root = $config->MXENV_ROOT;
foreach my $row ( $db_audit->retrieve_mxml_directories() ) {
    my ( $name, $received, $error )  = @{$row};
    $received =~ s/^\./$mxenv_root/; 
    $error    =~ s/^\./$mxenv_root/; 
    push @task_directories, { name => $name, received => $received, error => $error };
}

my $listtasks_script;
unless ( $listtasks_script = Mx::Ant->new( name => 'list_tasks', template => $config->XMLDIR . '/list_tasks.xml', target => 'listtasks', config => $config, logger => $logger, no_extra_logdir => 1, no_audit => 1 ) ) {
    $logger->logdie("ant session 'list_tasks' could not be initialized");
}

my $count = 0;
while ( 1 ) {
    if ( ++$count == 5 ) {
        Mx::MxML::Node->update_nr_messages( logger => $logger, oracle => $oracle, library => $sql_library, nodes => $nodes_ref, only_untaken => 0 );

        Mx::MxML::Node->audit( logger => $logger, db_audit => $db_audit, nodes => $nodes_ref );

        Mx::MxML::Node->check_thresholds( logger => $logger, nodes => $nodes_ref, threshold => $throughput_threshold, interval => 10, alert => $throughput_alert );

        $listtasks_script->run( exclusive => 1, no_output => 1 );

        my $timestamp = time();

        foreach my $line ( split /\n/, $listtasks_script->output ) {
			$logger->debug($line);
            if ( $line =~ / - Task: (\S+) - (.+) \| (.+) \| (.+)$/ ) {
                my $taskname     = $1;
                my $unblocked    = ( $2 eq 'unblocked' )    ? 'Y' : 'N';
                my $loading_data = ( $3 eq 'loading data' ) ? 'Y' : 'N';
                my $started      = ( $4 eq 'started' )      ? 'Y' : 'N';

                unless ( $db_audit->update_mxml_task( taskname => $taskname, unblocked => $unblocked, loading_data => $loading_data, started => $started, timestamp => $timestamp ) ) {
                    $logger->error("task $taskname is not defined in the task table");
                }
            }
        }

        $count = 0;
    }
    else {
        Mx::MxML::Node->update_nr_messages( logger => $logger, oracle => $oracle, library => $sql_library, nodes => $nodes_ref, only_untaken => 1 );
    }

    Mx::MxML::Node->hist_audit( logger => $logger, db_audit => $db_audit, nodes => $nodes_ref );

    Mx::MxML::Task->check_thresholds( logger => $logger, tasks => $tasks_ref, size_alert => $size_alert, timeout_alert => $timeout_alert );

    if ( @task_directories ) { 
        my $taskname  = $task_directories[ $task_directory_index ]->{name};
        my $error_dir = $task_directories[ $task_directory_index ]->{error};

        if ( -d $error_dir ) {
            unless ( opendir DIR, $error_dir ) {
                $logger->logdie("cannot access $error_dir: $!");
            }

            my $nr_files = 0;
            while ( readdir( DIR ) ) {
                next if $_ =~ /^\.+$/;
                $nr_files++;
            }

            closedir( DIR );

            if ( $nr_files ) {
                $import_alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $nr_files, $error_dir ], item => $taskname );
            }
        }

        $task_directory_index++;
        $task_directory_index = 0 if $task_directory_index > $#task_directories;
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
