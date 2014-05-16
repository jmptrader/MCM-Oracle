#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::DBaudit;
use Mx::Logfile;
use POSIX;

my $name = 'log';
 
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

#
# open a connection to the auditing database
#
my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $labels_ref = $config->LOGFILES;

my @labels = keys %{$labels_ref};

my @logfiles = ();

foreach my $label ( @labels ) {
    my @filenames = Mx::Logfile->get_filenames( label => $label, config => $config, logger => $logger );
    foreach my $filename ( @filenames ) {
        my $logfile = Mx::Logfile->new( path => $filename, label => $label, db_audit => $db_audit, config => $config, logger => $logger );
        push @logfiles, $logfile if $logfile;
    }
}

while ( 1 ) {
    foreach my $logfile ( @logfiles ) {
        $logfile->check();
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
