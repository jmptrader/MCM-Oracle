#!/usr/bin/env perl

use Mx::Config;
use Mx::Log;
use Mx::Process;
use Mx::DBaudit;
use Mx::Datamart::Scannerlog;

use Data::Dumper;

my $pid = $ARGV[0];

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'test10' );

my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $process = Mx::Process->new( pid => $pid, ppid => $$, uid => $<, command => 'blabla', light => 1, logger => $logger, config => $config );

$process->analyze_cmdline();

print $process->mx_scanner . "\n";

$process->{config} = undef;

print Dumper( $process );

my $scannerlog = Mx::Datamart::Scannerlog->new( parent => $process, db_audit => $db_audit, logger => $logger, config => $config );
