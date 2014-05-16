#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use RRDTool::OO;
use POSIX;

my $name = 'db_server_perf';

my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] ); 

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
my $hires_rrdfile = $collector->hires_rrdfile;
my $poll_interval = $collector->poll_interval;

my $syb_srv       = $config->SYB_SRV;
my $syb_ssh_login = $config->SYB_SSH_LOGIN;

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

my $command  = "/usr/bin/ssh -qn $syb_ssh_login\@$syb_srv ./sysperfstat_aix.pl $poll_interval";

unless ( open CMD, "$command|" ) {
    $logger->logdie("cannot execute $command: $!");
}

while ( my $line = <CMD> ) {
    chomp($line);

    if ( $line !~ /^[0-9:.]+$/ ) {
        $logger->error($line);
        next;
    }

    my ( $timestamp, $runqueue, $scanrate, $cpu_user, $cpu_system, $cpu_idle, $cpu_wait, $entitled_capacity ) = split ':', $line;

    unless ( $rrd->update( time => $timestamp, values => [
      $runqueue,
      $scanrate,
      $cpu_user,
      $cpu_system,
      $cpu_idle,
      $cpu_wait,
      $entitled_capacity,
    ] ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    next unless $hires_rrd;

    unless ( $hires_rrd->update( time => $timestamp, values => [
      $runqueue,
      $scanrate,
      $cpu_user,
      $cpu_system,
      $cpu_idle,
      $cpu_wait,
      $entitled_capacity,
    ] ) ) {
        $logger->error("cannot update $hires_rrdfile: " . $hires_rrd->error_message);
    }
}

close(CMD);

$process->remove_pidfile();
