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
use Mx::Murex;
use Mx::Macro;
use Mx::Alert;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: macro.pl [ -name <scriptname> ] [ -project <projectname> ] [ -xml <xmlfile> ] [ -ph <key:value> ] [ -cfg <cfgfile> ] [ -nick <nickname> ] [ -sched_js <stream> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <scriptname>      Name of the macro to execute.
 -project <projectname>  Name of the project to which the macro belongs.
 -xml <xmlfile>          Name of the xml file to use.
 -ph <key:value>         Name of a placeholder and its value (can be used repeatedly).
 -cfg <cfgfile>          Name of the file containing values for placeholders in the xml file.
 -nick <nickname>        If you want to override the default nickname.
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
my ($name, $project, $xml, @ph, $cfg, $nick, $sched_js, $mail, $mail_nok, $debug);

GetOptions(
    'name=s'        => \$name,
    'project=s'     => \$project,
    'xml=s'         => \$xml,
    'ph=s'          => \@ph,
    'cfg=s'         => \$cfg,
    'nick=s'        => \$nick,
    'sched_js=s'    => \$sched_js,
    'mail=s'        => \$mail,
    'mail_nok=s'    => \$mail_nok,
    'debug!'        => \$debug,
    'help'          => \&usage,
);

unless ( $name and $xml and $sched_js ) {
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

$logger->info("macro.pl $args");

my $hostname = Mx::Util->hostname;
$logger->info("hostname = $hostname"); 

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'macro', logger => $logger );
$audit->start($args);

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

my $entity;
if ( $sched_js ) {
    my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );
    $entity  = $scheduler->entity();
}

unless ( substr($xml, 0, 1) eq '/' ) {
    $xml = $config->PROJECT_XMLDIR . '/' . $xml;
}

my %cfghash = ();
foreach my $ph ( @ph ) {
    my ( $key, $value ) = $ph =~ /^(.+):(.+)$/;
    $cfghash{$key} = $value;
}

#
# determine the nick to use
#
$nick = $nick || Mx::Murex->session_nick( logger => $logger, config => $config );

#
# initialize the script
#
my $script;
unless ( $script = Mx::Macro->new( name => $name, entity => $entity, template => $xml, cfghash => \%cfghash, cfgfile => $cfg, nick => $nick, project => $project, sybase => $sybase, library => $sql_library, sched_jobstream => $sched_js, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::Macro::errstr, 1 );
}

$script->run( exclusive => 1, debug => $debug );

if ( $script->exitcode == 0 ) {
    $script->mail( address => $mail ) if $mail;
}
else {
    if ( $mail && $mail_nok ) {
        $mail .= ",$mail_nok";
    }
    elsif ( $mail_nok ) {
        $mail = $mail_nok;
    }
    $script->mail( address => $mail ) if $mail;
    $audit->end( $Mx::Macro::errstr, $script->exitcode );
}

$sybase->close();

$audit->end($args, 0);
