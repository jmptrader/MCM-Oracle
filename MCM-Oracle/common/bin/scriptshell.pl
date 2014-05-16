#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Context;
use Mx::Account;
use Mx::Oracle;
use Mx::SQLLibrary;
use Mx::Murex;
use Mx::Alert;
use Mx::ScriptShell;
use Mx::ProcScriptXML;
use Mx::Datamart::Batch;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: scriptshell.pl [ -name <scriptname> ] [ -xml <xmlfile> ] [ -split ] [ -project <projectname> ] [ -context <contextname> ] [ -nick <nickname> ] [ -sched_js <stream> ] [ -no_audit ] [ -debug ] [ -help ]

 -name <scriptname>      Name of the script to execute.
 -xml <xmlfile>          Name of the xml file to use.
 -split                  Split the XML into its items and execute each item separately.
 -project <projectname>  Name of the project to which the script belongs.
 -context <contextname>  Name of the context to use.
 -nick <nickname>        If you want to override the default nickname.
 -no_audit               Do not record the session.
 -sched_js <stream>      Jobstream name in the scheduler.
 -debug                  Generate a Murex trace file.
 -help                   Display this text.

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
my ($name, $xml, $do_split, $project, $context, $nick, $sched_js, $no_audit, $mail, $mail_nok, $debug);

GetOptions(
    'name=s'        => \$name,
    'xml=s'         => \$xml,
    'split!'        => \$do_split,
    'project=s'     => \$project,
    'context=s'     => \$context,
    'nick=s'        => \$nick,
    'sched_js=s'    => \$sched_js,
    'no_audit!'     => \$no_audit,
    'mail=s'        => \$mail,
    'mail_nok=s'    => \$mail_nok,
    'debug!'        => \$debug,
    'help'          => \&usage,
);

unless ( $name and $project and $sched_js ) {
    usage();
}

#
# read the configuration files
#
my $config  = Mx::Config->new();

$config->set_project_variables( $project );

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->PROJECT_LOGDIR, keyword => $sched_js );

$logger->info("scriptshell.pl $args");

my $hostname = Mx::Util->hostname;

$logger->info("Hostname = $hostname") ;

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'scriptshell', logger => $logger );

$audit->start($args);

#
# setup the database account
#
my $account_fin = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
my $account_rep = Mx::Account->new( name => $config->REP_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $oracle_fin = Mx::Oracle->new( database => $config->DB_FIN, username => $account_fin->name, password => $account_fin->password, logger => $logger, config => $config );
my $oracle_rep = Mx::Oracle->new( database => $config->DB_REP, username => $account_rep->name, password => $account_rep->password, logger => $logger, config => $config );

#
# open the Sybase connection
#
$oracle_fin->open();
$oracle_rep->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->DM_SQLLIBRARY, logger => $logger );

my $alert = Mx::Alert->new( name => 'batch_failure', config => $config, logger => $logger );

my $entity  = $config->DEFAULT_ENTITY;
my $runtype = $config->DEFAULT_RUNTYPE;

#
# create the proper account
#
my $mx_account;
if ( $context ) {
    my $context_obj;
    unless ( $context_obj = Mx::Context->new( name => $context, config => $config, logger => $logger ) ) {
        $audit->end("context $context cannot be found", 1);
    }
    my $mx_account;
    unless ( $mx_account = $context_obj->account() ) {
        my $user = $context_obj->user();
        $audit->end("account $user cannot be found", 1);
    }
}

unless ( substr($xml, 0, 1) eq '/' ) {
    $xml = $config->PROJECT_XMLDIR . '/' . $xml;
}

#
# determine the nick to use
#
$nick = $nick || Mx::Murex->batch_nick( logger => $logger, config => $config );

my $procscriptxml = Mx::ProcScriptXML->new( xml => $xml, logger => $logger );

my @procscriptxmls = $do_split ? $procscriptxml->split : ( $procscriptxml );

foreach my $psx ( @procscriptxmls ) {
    my $lxml  = $psx->xml;
    my $unit  = $psx->item_unit;

    my $lname;
    if ( $unit eq 'DATAMART.REPORTING.BATCHES.FEEDERS' or $unit eq 'DATAMART.REPORTING.BATCHES.PROCEDURES' ) {
        $lname = $psx->item_label;
    }
    else {
        $lname = $psx->item_name || $psx->name || $name;
    }

    my $script;
    if ( $unit eq 'DATAMART.REPORTING.BATCHES.FEEDERS' ) {
        my $extra_args;
        if ( $debug ) {
            $extra_args = '/SCANNER_NICKNAME:MXDEALSCANNER.ENGINEDEBUG';
        }

        unless ( $script = Mx::Datamart::Batch->new(
          name            => $lname,
          entity          => $entity,
          runtype         => $runtype,
          template        => $lxml,
          account         => $mx_account,
          nick            => $nick,
          extra           => $extra_args,
          noconfig        => 1,
          sched_jobstream => $sched_js,
          project         => $project,
          no_audit        => $no_audit,
          no_extra_logdir => $no_audit,
          oracle          => $oracle_fin,
          oracle_rep      => $oracle_rep,
          library         => $sql_library,
          config          => $config,
          logger          => $logger
        ) ) {
            $audit->end( $Mx::Datamart::Batch::errstr, 1 );
        }
    }
    else {
        unless ( $script = Mx::ScriptShell->new(
          name            => $lname,
          template        => $lxml,
          account         => $mx_account,
          nick            => $nick,
          sched_jobstream => $sched_js,
          project         => $project,
          no_audit        => $no_audit,
          no_extra_logdir => $no_audit,
          config          => $config,
          logger          => $logger
        ) ) {
            $audit->end( $Mx::ScriptShell::errstr, 1 );
        }
    }

    $script->run( exclusive => 1, debug => $debug );

    if ( $script->exitcode != 0 ) {
        $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $lname, $project, Mx::Error->description( $script->exitcode ) ], item => $lname );

        my $errstr = ( $unit eq 'DATAMART.REPORTING.BATCHES.FEEDERS' ) ? $Mx::Datamart::Batch::errstr : $Mx::ScriptShell::errstr;

        $audit->end( $errstr, $script->exitcode );
    }
}

$oracle_fin->close();
$oracle_rep->close();

$audit->end($args, 0);

