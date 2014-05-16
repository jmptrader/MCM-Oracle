#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Collector;
use Mx::Util;
use Mx::Secondary;
use Mx::Alert;
use RRDTool::OO;
use POSIX;

my $name = 'app_server_2_perf';

my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
my $poll_interval = $collector->poll_interval;

my $hostname      = Mx::Util->hostname();
my $scanrate_file = $config->AVG_SCANRATE_FILE;
$scanrate_file    =~ s/__APPL_SRV_SHORT__/$hostname/g;
 
my @perf_samples    = (); # array to calculate an 'average scanrate'
my $nr_perf_samples = int( 60 / $poll_interval );
$nr_perf_samples    = 10 if $nr_perf_samples < 10;

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


my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my $command = $config->BINDIR . "/sysperfstat.pl $poll_interval";

my $cpu_alert = Mx::Alert->new( name => 'average_cpu_load', config => $config, logger => $logger ); 
my $mem_alert = Mx::Alert->new( name => 'average_scan_rate', config => $config, logger => $logger ); 

unless ( open CMD, "$command|" ) {
    $logger->logdie("cannot execute $command: $!");
}

<CMD>; # skip the first line

while ( my $line = <CMD> ) {
    chomp($line);
    my ( $timestamp, @values ) = split ':', $line;

    my $avg_load = Mx::Secondary->avg_load();
    push @values, $avg_load;

    $cpu_alert->check( values => [ $avg_load ], item => $hostname );

    my $scanrate = $values[5];
    push @perf_samples, $scanrate;
    while ( @perf_samples > $nr_perf_samples ) {
        shift @perf_samples;
    }
    my $actual_nr_perf_samples = @perf_samples;
    my $total = 0;
    foreach my $sample ( @perf_samples ) {
        $total += $sample;
    }
    my $avg_scanrate = sprintf "%.2f", $total / $actual_nr_perf_samples;
 
    open FH, "> $scanrate_file";
    print FH $avg_scanrate;
    close(FH);

    $mem_alert->check( values => [ $avg_scanrate ], item => $hostname );

    unless ( $rrd->update( time => $timestamp, values => \@values ) ) {
        $logger->error("cannot update $rrdfile");
    }
}

close(CMD);

$process->remove_pidfile();
