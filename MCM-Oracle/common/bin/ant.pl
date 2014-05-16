#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Ant;
use Mx::OrchestAnt;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: ant.pl [ -name <scriptname> ] [ -xml <xmlfile> ] [ -target <target> ] [ -orchest ] [ -jopt <extra_args> ] [ -output ] [ -project <projectname> ] [ -sched_js <stream> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -name <scriptname>      Name of the script to execute.
 -xml <xmlfile>          Name of the xml file to use.
 -target <target>        Which ant target to use.
 -orchest                Launch an orchestrator ant instead of a normal ant script.
 -jopt <extra_args>      Extra arguments to be passed to the ant script.
 -output                 Show output on screen.
 -project <projectname>  Name of the project to which the script belongs.
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
my ($name, $xml, $target, $orchest, $jopt, $output, $project, $sched_js, $mail, $mail_nok, $debug);

GetOptions(
    'name=s'        => \$name,
    'xml=s'         => \$xml,
    'target=s'      => \$target,
    'orchest!'      => \$orchest,
    'jopt=s'        => \$jopt,
    'output!'       => \$output,
    'project=s'     => \$project,
    'sched_js=s'    => \$sched_js,
    'mail=s'        => \$mail,
    'mail_nok=s'    => \$mail_nok,
    'debug!'        => \$debug,
    'help'          => \&usage,
);

unless ( $name and $xml and $project and $sched_js ) {
    usage();
}

$orchest ||= 0;

#
# read the configuration files
#
my $config  = Mx::Config->new();

$config->set_project_variables( $project );

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => $sched_js );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'ant', logger => $logger );

$audit->start($args);

unless ( substr($xml, 0, 1) eq '/' ) {
    $xml = $config->PROJECT_XMLDIR . '/' . $xml;
}

#
# initialize the script
#
my $script;
if ( $orchest ) {
    unless ( $script = Mx::OrchestAnt->new( name => $name, template => $xml, target => $target, jopt => $jopt, sched_jobstream => $sched_js, project => $project, config => $config, logger => $logger ) ) {
        $audit->end( $Mx::OrchestAnt::errstr, 1 );
    }
}
else {
    unless ( $script = Mx::Ant->new( name => $name, template => $xml, target => $target, jopt => $jopt, sched_jobstream => $sched_js, project => $project, config => $config, logger => $logger ) ) {
        $audit->end( $Mx::Ant::errstr, 1 );
    }
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

    my $errstr = ( $orchest ) ? $Mx::OrchestAnt::errstr : $Mx::Ant::errstr;

    $audit->end( $errstr, $script->exitcode );
}

$audit->end($args, 0);

