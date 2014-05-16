#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Oracle;
use Mx::Datamart::Report;
use Mx::Datamart::Feedertable;
use Mx::PerlScript;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: dm_report.pl [ -name <reportname> ] [ -label <reportlabel> ] [ -id <feedertable_id> ] [ -project <project> ] [ -sched_js <stream> ] [ -help ]

 -name <reportname>                  Name of the report.
 -label <reportlabel>                Configuration label of the report.
 -id <feedertable_id>                ID of the feedertable containing the data.
 -project <projectname>              Name of the project to which the report belongs.
 -sched_js <stream>                  Jobstream name in the scheduler.
 -help                               Display this text.

EOT
;
    exit;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($name, $label, $feedertable_id, $project, $sched_js);

GetOptions(
    'name=s'     => \$name,
    'label=s'    => \$label,
    'id=i'       => \$feedertable_id,
	'project=s'  => \$project,
	'sched_js=s' => \$sched_js,
    'help'       => \&usage,
);

unless ( $name && $label && $feedertable_id && $project && $sched_js ) {
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
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => $sched_js );

$logger->info("dm_report.pl $args");

#
# create historical script
#
my $script = Mx::PerlScript->new( logger => $logger, config => $config );

my $db_audit = $script->db_audit;

#
# setup the database account
#
my $account_rep = Mx::Account->new( name => $config->REP_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $oracle_rep  = Mx::Oracle->new( database => $config->DB_REP, username => $account_rep->name, password => $account_rep->password, logger => $logger, config => $config );

#
# open the Sybase connection
#
$oracle_rep->open();

my $feedertable;
unless ( $feedertable = Mx::Datamart::Feedertable->retrieve( id => $feedertable_id, db_audit => $db_audit, logger => $logger ) ) {
    $script->fail_and_die("no feedertable with id $feedertable_id found");
}

my $tablename = $feedertable->name;
my $ref_data  = $feedertable->ref_data;

$logger->info("feedertable: $tablename - ref data: $ref_data");

$tablename =~ s/\.REP$/_REP/;

#
# create historical report
#
my $report;
unless ( $report = Mx::Datamart::Report->new(
  name     => $name,
  label    => $label,
  location => $Mx::Datamart::Report::LOCATION_DATA,
  script   => $script
  ) ) {
    $script->fail_and_die("report initialisation failed");
}

$report->open( mode => $Mx::Datamart::Report::MODE_WRITE );

my $query = 'select ' . ( join ',', $report->db_columns ) . ' from ' .  $tablename . ' where M_REF_DATA = ?';

$report->add_records( resultset => $oracle_rep->query( query => $query, values => [ $ref_data ] ) );

$oracle_rep->close;

$report->finish;

$script->finish;
