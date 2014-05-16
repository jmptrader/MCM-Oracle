#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Account;
use RRDTool::OO;
use Time::Local;
use POSIX;

my $name = 'syb_db_perf';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
my $poll_interval = $collector->poll_interval;
 
my $dsquery       = $config->retrieve('DSQUERY');
my $syb_dir       = $config->retrieve('SYB_DIR');
my $db_user       = $config->retrieve('MX_TSUSER');
my $packetsize    = $config->retrieve('SYB_PACKETSIZE');

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


my $account  = Mx::Account->new( name => $db_user, config => $config, logger => $logger );
my $password = $account->password();

my $rrd  = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my $isql = $config->retrieve('SYB_DIR') . '/' . $config->retrieve('SYB_OCS') . '/bin/isql';
my $command = "$isql -A$packetsize -b -S$dsquery -U$db_user -P$password <<EOF
exec sp__stat
go
EOF";

unless ( open CMD, "$command|" ) {
    $logger->logdie("cannot execute $command: $!");
}

while ( my $line = <CMD> ) {
    chomp($line);
    if ( $line =~ /^\s*(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\s+([0-9 ]+)$/ ) {
        my $year   = $1 - 1900;
        my $month  = $2 - 1;
        my $day    = $3;
        my $hour   = $4;
        my $min    = $5;
        my $sec    = $6;
        my @values = split ' ', $7;
        my $time   = timelocal( $sec, $min, $hour, $day, $month, $year );
        unless ( $rrd->update( time => $time, values => \@values ) ) {
            $logger->error("cannot update $rrdfile: " . $rrd->error_message);
        }
    }
    else {
        $logger->error($line);
    }
}

close(CMD);

$process->remove_pidfile();
