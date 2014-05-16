#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use POSIX;

my $name = 'check';
 
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

Mx::Collector->init_disabled_collectors( config => $config );
 
#
# get a list of all the configured collectors
#
my @collectors = Mx::Collector->list( config => $config, logger => $logger );

while ( 1 ) {
    foreach my $collector ( @collectors ) {
        next if $collector->is_disabled;
        next unless $collector->location == 0;
        unless ( $collector->check ) {
            $collector->start;
        }
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
