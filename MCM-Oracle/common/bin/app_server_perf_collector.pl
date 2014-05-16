#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Collector;
use Mx::Util;
use Mx::Alert;
use Mx::Solaris::Sysperfstat;
use RRDTool::OO;
use List::Util qw(sum min);
use POSIX;


my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );

my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
my $hostname    = Mx::Util->hostname();

my ( $location ) = grep { Mx::Util->hostname( $app_servers[$_] ) eq $hostname } 0..$#app_servers;

my $name = 'app_server_' . $location . '_perf';

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
my $hires_rrdfile = $collector->hires_rrdfile;
my $poll_interval = $collector->poll_interval;

my $scanrate_file = $config->AVG_SCANRATE_FILE;
 
my @perf_samples    = (); # array to calculate an 'average scanrate'
my $nr_perf_samples = min( int( 60 / $poll_interval ), 10 );

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

my $rrd       = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );
my $hires_rrd = RRDTool::OO->new( file => $hires_rrdfile, raise_error => 0 ) if $hires_rrdfile;

my $cpu_alert = Mx::Alert->new( name => 'average_cpu_load', config => $config, logger => $logger ); 
my $mem_alert = Mx::Alert->new( name => 'average_scan_rate', config => $config, logger => $logger ); 

my $stat = Mx::Solaris::Sysperfstat->new( logger => $logger );

while ( 1 ) {
    $stat->refresh;

    $cpu_alert->check( values => [ $stat->load ], item => $hostname );

    push @perf_samples, $stat->smem;
    shift @perf_samples while ( @perf_samples > $nr_perf_samples );
    
    my $avg_scanrate = sprintf "%.2f", ( sum( @perf_samples ) / @perf_samples );
 
    open FH, "> $scanrate_file";
    print FH $avg_scanrate;
    close(FH);

    $mem_alert->check( values => [ $avg_scanrate ], item => $hostname );

    unless ( $rrd->update( time => $stat->timestamp, values => [
      $stat->ucpu,
      $stat->umem,
      $stat->udsk,
      $stat->unet,
      $stat->scpu,
      $stat->smem,
      $stat->sdsk,
      $stat->snet,
      $stat->load,
    ] ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    unless ( $hires_rrd ) {
        sleep $poll_interval;
        next;
    }

    unless ( $hires_rrd->update( time => $stat->timestamp, values => [
      $stat->ucpu,
      $stat->umem,
      $stat->udsk,
      $stat->unet,
      $stat->scpu,
      $stat->smem,
      $stat->sdsk,
      $stat->snet,
      $stat->load,
    ] ) ) {
        $logger->error("cannot update $hires_rrdfile: " . $hires_rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
