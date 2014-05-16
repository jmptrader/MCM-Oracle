#!/usr/bin/env perl

use strict;

use Mx::Config;
use Mx::Log;
use Getopt::Long;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: nowait.pl [ -project <projectname> ] [ -sched_js <stream> ] [ -help ]
 
 -project <projectname>     Name of the project.
 -sched_js <stream>         Jobstream name in the scheduler.
 -help                      Display this text.
 
EOT
;
    exit 1;
}
 
#
# process the commandline arguments
#
my ($project, $sched_js);
 
GetOptions(
    'project=s'    => \$project,
    'sched_js=s'   => \$sched_js,
    'help'         => \&usage
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
        
my $nowait_flag = $config->PROJECT_RUNDIR . '/' . $sched_js . '.nowait';

unless ( open FH, ">$nowait_flag" ) {
    $logger->logfail("cannot create nowait flag $nowait_flag: $!");
}
close(FH);

$logger->info("nowait flag $nowait_flag created");

exit 0;
