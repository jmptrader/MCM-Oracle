#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Alert;
use RRDTool::OO;
use POSIX;

my $name = 'db_server_perf2';

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
my $syb_loadfile  = $config->SYB_LOADFILE;

my @perf_samples    = (); # array to calculate an 'average load'
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

my $rrd       = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );
my $hires_rrd = RRDTool::OO->new( file => $hires_rrdfile, raise_error => 0 ) if $hires_rrdfile;

my $command  = "/usr/bin/ssh -qn $syb_ssh_login\@$syb_srv /usr/bin/lparstat $poll_interval";

my $alert = Mx::Alert->new( name => 'sybase_entitlement', config => $config, logger => $logger );

unless ( open CMD, "$command|" ) {
    $logger->logdie("cannot execute $command: $!");
}

while ( my $line = <CMD> ) {
    chomp($line);

    if ( my @values = $line =~ /^\s*(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+/ ) {

        my $entc = $6;
        push @perf_samples, $entc;
        while ( @perf_samples > $nr_perf_samples ) {
            shift @perf_samples;
        }
        my $actual_nr_perf_samples = @perf_samples;
        my $total = 0;
        foreach my $sample ( @perf_samples ) {
            $total += $sample;
        }
        my $avg_perf = sprintf "%.2f", $total / $actual_nr_perf_samples;

        open FH, "> $syb_loadfile";
        print FH $avg_perf;
        close(FH);

        unless ( $rrd->update( time => time(), values => \@values ) ) {
            $logger->error("cannot update $rrdfile: " . $rrd->error_message);
        }

        $alert->check( values => [ $entc ] );

        next unless $hires_rrd;

        unless ( $hires_rrd->update( time => time(), values => \@values ) ) {
            $logger->error("cannot update $hires_rrdfile: " . $hires_rrd->error_message);
        }
    }
}

close(CMD);

$process->remove_pidfile();
