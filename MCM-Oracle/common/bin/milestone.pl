#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Scheduler;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: milestone.pl [ -name <milestone> ] [ -start|-end ] [ -project <projectname> ] [ -entity <entity> ] [ -runtype <runtype> ] [ -sched_js <stream> ] [ -help ]

 -name <milestone>               Name of the milestone to record.
 -start                          Indicates start of the milestone.
 -end                            Indicates end of the milestone.
 -project <projectname>          Name of the project to which the milestone belongs.
 -entity <entity>                Name of  the entity.
 -runtype <runtype>              Type of run. Possible values: O, 1, X, V or N
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
my ($name, $start, $end, $project, $entity, $runtype, $sched_js);

GetOptions(
    'name=s'           => \$name,
    'start'            => \$start,
    'end'              => \$end,
    'project=s'        => \$project,
    'entity=s'         => \$entity,
    'runtype=s'        => \$runtype,
    'sched_js=s'       => \$sched_js,
    'help'             => \&usage,
);

unless ( $name and $project and $sched_js ) {
    usage();
}

if ( $start and $end ) {
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

$logger->info("milestone.pl $args");

my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );
$entity  = $entity  || $scheduler->entity();
$runtype = $runtype || $scheduler->runtype();


my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );


if ( $start ) {
    $db_audit->record_milestone_start( name => $name, project => $project, entity => $entity, runtype => $runtype, sched_jobstream => $sched_js );
}
elsif ( $end ) {
    $db_audit->record_milestone_end( name => $name, project => $project, entity => $entity, runtype => $runtype, sched_jobstream => $sched_js );
}
else {
    $db_audit->record_milestone( name => $name, project => $project, entity => $entity, runtype => $runtype, sched_jobstream => $sched_js );
}

$db_audit->close();


