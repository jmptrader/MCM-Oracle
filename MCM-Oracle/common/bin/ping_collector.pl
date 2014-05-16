#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Network::Ping;
use RRDTool::OO;
use POSIX;

my $name = 'ping';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
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

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

#
# get a list of all the configured pings
#
my @pings = Mx::Network::Ping->retrieve_all( logger => $logger, config => $config );

my $total_count = 0;
map { $total_count += $_->count } @pings;

if ( $total_count > $poll_interval ) {
    $logger->logdie("total number of ping counts ($total_count) is bigger than the poll interval ($poll_interval)");
}

$poll_interval -= $total_count;

while ( 1 ) {
    my %values = ();
    foreach my $ping ( @pings ) {
        my $name = $ping->name;
        $name =~ s/ /_/g;
        $ping->execute; 
        $values{ $name } = $ping->time; 
    }

    unless ( $rrd->update( time => time(), values => \%values ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
