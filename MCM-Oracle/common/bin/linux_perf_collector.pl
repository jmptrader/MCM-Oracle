#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Collector;
use Mx::Linux::Sysperfstat;
use RRDTool::OO;
use POSIX;

my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );

my $name = 'app_server_0_perf';

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

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my $stat = Mx::Linux::Sysperfstat->new( config => $config, logger => $logger );

while ( 1 ) {
    $stat->refresh;

    unless ( $rrd->update( time => $stat->timestamp, values => [
      $stat->ucpu_user,
      $stat->ucpu_system,
      $stat->ucpu_idle,
      $stat->ucpu_iowait,
      $stat->umem,
      $stat->uswap,
      $stat->udsk_read,
      $stat->udsk_write,
      $stat->unet_rx,
      $stat->unet_tx,
      $stat->load,
    ] ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
