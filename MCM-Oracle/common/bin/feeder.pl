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
use Mx::Scheduler;
use Mx::Murex;
use Mx::ScriptShell;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: feeder.pl [ -name <feedername> ] [ -project <projectname> ] [ -nick <nickname> ] [ -sched_js <stream> ] [ -no_audit ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <feedername>      Name of the batch of feeders to execute.
 -project <projectname>  Name of the project to which the feeder belongs.
 -nick <nickname>        If you want to override the default nickname.
 -no_audit               Do not record the session.
 -sched_js <stream>      Jobstream name in the scheduler.
 -mail <addresses>       Adresses to which a status report must be sent.
 -mail_nok <addresses>   Adresses to which a status report must be sent only in case of failure.
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
my ($name, $project, $nick, $sched_js, $no_audit, $mail, $mail_nok, $debug);

GetOptions(
    'name=s'        => \$name,
    'project=s'     => \$project,
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
my $logger  = Mx::Log->new( directory => $config->PROJECT_LOGDIR, keyword => $sched_js );

$logger->info("feeder.pl $args");

my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );
my $entity    = $scheduler->entity();
my $context   = $config->retrieve("ENTITIES.$entity.context");

my $hostname = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'scriptshell', logger => $logger );

$audit->start($args);

#
# create the proper account
#
my $context_obj;
unless ( $context_obj = Mx::Context->new( name => $context, config => $config, logger => $logger ) ) {
    $audit->end("context $context cannot be found", 1);
}
my $mx_account;
unless ( $mx_account = $context_obj->account() ) {
    my $user = $context_obj->user();
    $audit->end("account $user cannot be found", 1);
}

my $xml = $config->XMLDIR . '/batch_feeders.xml';

#
# determine the nick to use
#
$nick = $nick || Mx::Murex->batch_nick( logger => $logger, config => $config );

#
# initialize the script
#
my $scriptshell;
unless ( $scriptshell = Mx::ScriptShell->new( name => $name, template => $xml, account => $mx_account, nick => $nick, sched_jobstream => $sched_js, entity => $entity, project => $project, no_audit => $no_audit, no_extra_logdir => $no_audit, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::ScriptShell::errstr, 1 );
}

$scriptshell->run( exclusive => 1, debug => $debug );

if ( $scriptshell->exitcode == 0 ) {
    $scriptshell->mail( address => $mail ) if $mail;
}
else {
    if ( $mail && $mail_nok ) {
        $mail .= ",$mail_nok";
    }
    elsif ( $mail_nok ) {
        $mail = $mail_nok;
    }
    $scriptshell->mail( address => $mail ) if $mail;
    $audit->end( $Mx::ScriptShell::errstr, $scriptshell->exitcode );
}

$audit->end($args, 0);

