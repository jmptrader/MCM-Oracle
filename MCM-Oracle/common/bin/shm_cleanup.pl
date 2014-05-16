#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::IPC::SHM;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: shm_cleanup.pl [ -project <projectname> ] [ -sched_js <stream> ] [ -help ]

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

my @shms = Mx::IPC::SHM->retrieve_all( owner => $config->MXUSER, nr_attachments => 0, logger => $logger, config => $config );

foreach my $shm ( @shms ) {
    $shm->cleanup();
}

exit 0;
