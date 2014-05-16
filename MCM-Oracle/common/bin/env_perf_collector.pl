#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Util;
use Mx::Collector;
use RRDTool::OO;
use POSIX;

my $name = 'env_perf';
 
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

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my $app_server  = Mx::Util->hostname();

my %users = Mx::Config->users( $app_server );  

my %usernames = ();
while ( 1 ) {
    my %values = ();
    foreach my $entry ( Mx::Process->full_list( logger => $logger ) ) {
        my ( $uid, $pcpu, $pmem ) = @{$entry};

        my $username;
        unless ( $username = $usernames{$uid} ) {
            $username = $usernames{$uid} = ( getpwuid( $uid ) )[0];
        } 

        my $env = $users{$username} || 'OTHER';

        $values{"cpu_$env"} += $pcpu;
        $values{"mem_$env"} += $pmem;
    }

    unless ( $rrd->update( time => time(), values => \%values ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
