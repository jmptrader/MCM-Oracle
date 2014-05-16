#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Error;
use Mx::Audit;
use Mx::Context;
use Mx::Account;
use Mx::Oracle;
use Mx::SQLLibrary;
use Mx::Util;
use Mx::Datamart::Batch;
use Mx::Alert;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: dm_batch.pl [ -name <batchname> ] [ -xml <xmlfile> ] [ -project <projectname> ] [ -context <contextname> ] [ -entity <entity> ] [ -runtype <runtype> ] [ -mds <marketdata set> ] [ -sched_js <stream> ] [ -nick <nickname> ] [ -engines <nr of engines> ] [ -noconfig ] [ -norun ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <batchname>               Name of the batch to execute.
 -xml <xmlfile>                  Override the default xml (dm_batch.xml).
 -project <projectname>          Name of the project to which the batch belongs.
 -context <contextname>          Name of the context to use.
 -entity <entity>                Name of the entity for which to run.
 -runtype <runtype>              Type of run. Possible values: O, 1, X, V or N.
 -mds <marketdata set>           Label of the marketdata set to use.
 -sched_js <stream>              Jobstream name in the scheduler.
 -engines <nr of engines>        Number of engines via the scanner template.
 -nick <nickname>                Override the default nick name.
 -noconfig                       Do not update the configuration of the batch (filters, scanner & exception template).
 -norun                          Update the configuration of the batch but do not run the batch.
 -mail <addresses>               Adresses to which a status report must be sent.
 -mail_nok <addresses>           Adresses to which a status report must be sent only in case of failure.
 -debug                          Generate a Murex trace file.
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
my ($name, $xml, $project, $entity, $runtype, $context, $mds, $sched_js,  $nick, $nr_engines, $noconfig, $norun, $mail, $mail_nok, $debug, $remote_delay);

GetOptions(
    'name=s'           => \$name,
    'xml=s'            => \$xml,
    'project=s'        => \$project,
    'context=s'        => \$context,
    'entity=s'         => \$entity,
    'runtype=s'        => \$runtype,
    'mds=s'            => \$mds,
    'sched_js=s'       => \$sched_js,
    'nick=s'           => \$nick,
    'engines=s'        => \$nr_engines,
    'noconfig!'        => \$noconfig,
    'norun!'           => \$norun,
    'mail=s'           => \$mail,
    'mail_nok=s'       => \$mail_nok,
    'debug!'           => \$debug,
    'remote_delay=s'   => \$remote_delay,
    'help'             => \&usage,
);

unless ( $name and $project and $sched_js ) {
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

$logger->info("dm_batch.pl $args");

my $hostname  = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'dm_batch', logger => $logger ); 
$audit->start( $args );

#
# setup the database account
#
my $account_fin = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
my $account_rep = Mx::Account->new( name => $config->REP_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $oracle_fin  = Mx::Oracle->new( database => $config->DB_FIN, username => $account_fin->name, password => $account_fin->password, logger => $logger, config => $config );
my $oracle_rep  = Mx::Oracle->new( database => $config->DB_REP, username => $account_rep->name, password => $account_rep->password, logger => $logger, config => $config );

#
# open the Sybase connection
#
$oracle_fin->open();
$oracle_rep->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->DM_SQLLIBRARY, logger => $logger );

my $scheduler;
if ( $sched_js ) {
    if ( $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config ) ) {
        $entity  = $entity  || $scheduler->entity();
        $runtype = $runtype || $scheduler->runtype();
        $context = $context || $config->retrieve("%ENTITIES%$entity%context");
        $mds     = $mds;
    }
}

my $alert = Mx::Alert->new( name => 'batch_failure', config => $config, logger => $logger );

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

my $template = $xml || ( $config->XMLDIR . '/dm_batch.xml' );

#
# determine the nick to use
#
$nick = $nick || Mx::Murex->batch_nick( logger => $logger, config => $config );

my $extra_args;
if ( $debug ) {
    $extra_args = '/SCANNER_NICKNAME:MXDEALSCANNER.ENGINEDEBUG';
}

#
# initialize the script
#
my $script;
unless ( $script = Mx::Datamart::Batch->new( 
  name            => $name,
  entity          => $entity,
  runtype         => $runtype,
  mds             => $mds,
  template        => $template,
  account         => $mx_account,
  nick            => $nick,
  extra           => $extra_args,
  sched_jobstream => $sched_js,
  project         => $project,
  nr_engines      => $nr_engines,
  noconfig        => $noconfig,
  norun           => $norun,
  remote_delay    => $remote_delay,
  oracle          => $oracle_fin,
  oracle_rep      => $oracle_rep,
  library         => $sql_library,
  config          => $config,
  logger          => $logger
  ) ) {
    $audit->end( $Mx::Datamart::Batch::errstr, 1 );
}

$script->run( exclusive => 1, debug => $debug );

if ( $norun ) {
    $ENV{MXID} = $script->id;
    Mx::Process->run( command => 'dm_before.pl', logger => $logger, config => $config );
    exit 0;
}

unless ( $script->exitcode == 0 ) {
    $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $name, $project, Mx::Error->description( $script->exitcode ) ], item => $name );

    if ( $mail && $mail_nok ) {
        $mail .= ",$mail_nok";
    }
    elsif ( $mail_nok ) {
        $mail = $mail_nok;
    }
    $script->mail( address => $mail ) if $mail;

    my $exitcode = ( $script->exitcode == $Mx::Error::DYNTABLE_OVERFLOW ) ? 0 : $script->exitcode; # ignore overflows

    $audit->end( $Mx::Datamart::Batch::errstr, $exitcode );
}

$script->mail( address => $mail ) if $mail;

print $script->id, "\n";

$audit->end( $args, 0 );

