#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Scheduler;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: pipe_cleanup.pl [ -project <projectname> ] [ -sched_js <stream> ] [ -pipe <pipe1,pipe2,...> ] [ -help ]

 -project <projectname>          Name of the project.
 -sched_js <stream>              Jobstream name in the scheduler.
 -pipe <pipe1,pipe2,..>          Names of the pipes which must be cleaned up.
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
my ($project, $sched_js, $pipes);

GetOptions(
    'project=s'        => \$project,
    'sched_js=s'       => \$sched_js,
    'pipe=s'           => \$pipes,
    'help'             => \&usage,
);

unless ( $project and $sched_js and $pipes ) {
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

my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );

my @pipes = split ',', $pipes;

foreach my $pipe ( @pipes ) {
    $scheduler->cleanup( pipe => $pipe );
}

