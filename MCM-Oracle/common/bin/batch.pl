#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Context;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Util;
use Mx::Batch;
use Mx::Alert;
use Mx::Error;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: batch.pl [ -name <batchname> ] [ -project <projectname> ] [ -context <contextname> ] [ -entity <entity> ] [ -runtype <runtype> ] [ -mds <marketdata set> ] [ -sched_js <stream> ] [ -pipe <pipe1,pipe2,...> ] [ -no_pipe_cleanup ] [ -nick <nickname> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <batchname>               Name of the batch to execute.
 -project <projectname>          Name of the project to which the batch belongs.
 -context <contextname>          Name of the context to use.
 -entity <entity>                Name of  then entity for which to run.
 -runtype <runtype>              Type of run. Possible values: O, 1, X, V or N
 -mds <marketdata set>           Label of the marketdata set to use.
 -sched_js <stream>              Jobstream name in the scheduler.
 -pipe <pipe1,pipe2,..>          Names of the pipes where the sessionid must be stored.
 -no_pipe_cleanup                Do not cleanup the pipe file(s) (default is to remove them)
 -nick <nickname>                Override the default nick name
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
my ($name, $project, $entity, $runtype, $context, $mds, $sched_js, $pipes, $no_pipe_cleanup, $nick, $mail, $mail_nok, $debug, $remote_delay);

GetOptions(
    'name=s'           => \$name,
    'project=s'        => \$project,
    'context=s'        => \$context,
    'entity=s'         => \$entity,
    'runtype=s'        => \$runtype,
    'mds=s'            => \$mds,
    'sched_js=s'       => \$sched_js,
    'pipe=s'           => \$pipes,
    'no_pipe_cleanup!' => \$no_pipe_cleanup,
    'nick=s'           => \$nick,
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

$logger->info("batch.pl $args");

my $hostname    = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'batch', logger => $logger ); 
$audit->start( $args );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

#
# open the Sybase connection
#
$sybase->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

my $scheduler;
if ( $sched_js ) {
    $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );
    $entity  = $entity  || $scheduler->entity();
    $runtype = $runtype || $scheduler->runtype();
    $context = $context || $config->retrieve("ENTITIES.$entity.context");
    $mds     = $mds     || $config->retrieve("ENTITIES.$entity.mds-$runtype") if $runtype ne 'N';
}

my @pipes = ();
if ( $pipes ) {
    @pipes = split ',', $pipes;
}

my $alert = Mx::Alert->new( name => 'batch_failure', config => $config, logger => $logger );

#
# create the proper account
#
unless ( $context ) {
    $audit->end("no context specified");
}
my $context_obj;
unless ( $context_obj = Mx::Context->new( name => $context, config => $config, logger => $logger ) ) {
    $audit->end("context $context cannot be found", 1);
}
my $mx_account;
unless ( $mx_account = $context_obj->account() ) {
    my $user = $context_obj->user();
    $audit->end("account $user cannot be found", 1);
}

my $template = $config->XMLDIR . '/batch.xml';

#
# determine the nick to use
#
$nick = $nick || Mx::Murex->batch_nick( logger => $logger, config => $config );

#
# initialize the script
#
my $script;
unless ( $script = Mx::Batch->new( name => $name, entity => $entity, runtype => $runtype, mds => $mds, template => $template, account => $mx_account, nick => $nick, sched_jobstream => $sched_js, project => $project, remote_delay => $remote_delay, sybase => $sybase, library => $sql_library, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::Batch::errstr, 1 );
}

$script->run( exclusive => 1, debug => $debug );

if ( $script->exitcode == 0 or $script->exitcode == $Mx::Error::DYNTABLE_OVERFLOW ) {
    foreach my $pipe ( @pipes ) {
        $scheduler->cleanup( pipe => $pipe ) unless $no_pipe_cleanup;
        $scheduler->write( pipe => $pipe, item => $script->id ) if $scheduler;
    }
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

    $audit->end( $Mx::Batch::errstr, $exitcode );
}

#
# check if some post-processing must be performed on the outputfile(s)
#
if ( my $command = $script->command  ) {
    $command .= ' ' . $script->id;
 
    my ($success, $rc ) = Mx::Process->run( command => $command, config => $config, logger => $logger );
 
    if ( ! $success or $rc ) {
        if ( $mail && $mail_nok ) {
            $mail .= ",$mail_nok";
        }
        elsif ( $mail_nok ) {
            $mail = $mail_nok;
        }
        $script->mail( address => $mail ) if $mail;
        $audit->end( 'post-processing failed', $rc );
    }
}

$script->mail( address => $mail ) if $mail;

print $script->id, "\n";

$audit->end( $args, 0 );

