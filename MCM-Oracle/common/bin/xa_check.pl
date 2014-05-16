#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Util;
use Getopt::Long;
use IO::File;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: xa_check.pl [ -project <projectname> ] [ -sched_js <stream> ] [ -help ]

 -project <projectname>          Name of the project.
 -sched_js <stream>              Jobstream name in the scheduler.
 -help                           Display this text.

EOT
;
    exit 1;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($project, $sched_js);

GetOptions(
    'project=s'        => \$project,
    'sched_js=s'       => \$sched_js,
    'help'             => \&usage,
);

unless ( $project and $sched_js ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

$config->set_project_variables( $project );

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->PROJECT_LOGDIR, keyword => $sched_js );

$logger->info("checking if any XA transactions are remaining");

my ( $success, $rc ) = Mx::Process->run( command => 'launchmxj.app -xalog', directory => $config->MXENV_ROOT, logger => $logger, config => $config );

if ( ! $success or $rc ) {
    $logger->logdie("command failed");
}

sleep 5;

my $logfile = $config->MXENV_ROOT . '/logs/' . Mx::Util->hostname( $config->MXJ_FILESERVER_HOST ) . '.xatransactionlogger.log';

my $blocked = 1;

my $fh;
unless ( $fh = IO::File->new( $logfile ) ) {
    $logger->logdie("cannot open $logfile: $!");
}
my @lines = <$fh>;
$fh->close();

my $last_line = pop @lines;
$blocked = 0 if $last_line eq "No remaining transactions\n";

if ( $blocked ) {
    $logger->error("some XA transactions are remaining. Please consult $logfile");
}
else {
    $logger->info("no remaining XA transactions");
}

exit $blocked;
