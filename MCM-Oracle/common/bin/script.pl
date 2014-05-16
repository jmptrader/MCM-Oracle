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
use Mx::Murex;
use Mx::Script;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: script.pl [ -name <scriptname> ] [ -xml <xmlfile> ] [ -output ] [ -project <projectname> ] [ -nick <nickname> ] [ -sched_js <stream> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <scriptname>      Name of the script to execute.
 -xml <xmlfile>          Name of the xml file to use.
 -output                 Show output on screen.
 -project <projectname>  Name of the project to which the script belongs.
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
my ($name, $xml, $output, $project, $nick, $sched_js, $mail, $mail_nok, $debug);

GetOptions(
    'name=s'        => \$name,
    'xml=s'         => \$xml,
    'output!'       => \$output,
    'project=s'     => \$project,
    'nick=s'        => \$nick,
    'sched_js=s'    => \$sched_js,
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
my $config = Mx::Config->new();

$config->set_project_variables( $project );

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->PROJECT_LOGDIR, keyword => $sched_js );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'script', logger => $logger );

$audit->start($args);

unless ( substr($xml, 0, 1) eq '/' ) {
    $xml = $config->XMLDIR . '/' . $xml;
}

#
# initialize the script
#
my $script;
unless ( $script = Mx::Script->new( name => $name, template => $xml, nick => $nick, sched_jobstream => $sched_js, project => $project, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::Script::errstr, 1 );
}

$script->run( exclusive => 1, debug => $debug );

print $script->output if $output;

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
    $audit->end( $Mx::Script::errstr, $script->exitcode );
}

$audit->end($args, 0);

