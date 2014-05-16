#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::DBaudit;
use Mx::Murex;
use Mx::TWS::Job;
use POSIX;

my $name = 'tws';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );

my $tws_dir;
if ( -d '/opt/maestro/stdlist' ) {
    $tws_dir = '/opt/maestro/stdlist';
}
elsif ( -d '/opt/maestro/TWS/stdlist' ) {
    $tws_dir = '/opt/maestro/TWS/stdlist';
}
else {
    $logger->logdie("cannot locate a TWS directory");
}
 
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

#
# open a connection to the auditing database
#
my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $tws_date = Mx::Murex->calendardate();

$tws_dir .= '/' . substr( $tws_date, 0, 4 ) . '.' . substr( $tws_date, 4, 2 ) . '.' . substr( $tws_date, 6, 2 );

unless( chdir( $tws_dir ) ) {
    $logger->logdie("cannot cd to $tws_dir: $!");
}

my @running_jobs = ();

while ( 1 ) {
    my @new_list;
    foreach my $job ( @running_jobs ) {
        next if $job->update;
        next if $job->endtime && $job->endtime == -1;
        push @new_list, $job;
    }

    @running_jobs = @new_list;

    my @logfiles = Mx::TWS::Job->scan_jobs( logger => $logger );

    foreach my $logfile ( @logfiles ) {
        if ( my $result = Mx::TWS::Job->parse_logfile( logfile => $logfile, logger => $logger ) ) {
            my $job = Mx::TWS::Job->new( %{$result}, mode => 'auto', tws_date => $tws_date, db_audit => $db_audit, config => $config, logger => $logger );

            push @running_jobs, $job unless $job->endtime;
        }
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
