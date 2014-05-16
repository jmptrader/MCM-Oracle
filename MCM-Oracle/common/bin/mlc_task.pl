#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use MLC::Task;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: mlc_task.pl [ -name <taskname> ] [ -xml <xmlfile> ] [ -log ] [ -sched_js <stream> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -help ]

 -name <scriptname>      Name of the task to execute.
 -xml <xmlfile>          Name of the xml file to use.
 -log                    Move the resulting logfiles.
 -sched_js <stream>      Jobstream name in the scheduler.
 -mail <addresses>       Adresses to which a status report must be sent.
 -mail_nok <addresses>   Adresses to which a status report must be sent only in case of failure.
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
my ($name, $xml, $move_logfiles, $sched_js, $mail, $mail_nok);

GetOptions(
    'name=s'        => \$name,
    'xml=s'         => \$xml,
    'log!'          => \$move_logfiles,
    'sched_js=s'    => \$sched_js,
    'mail=s'        => \$mail,
    'mail_nok=s'    => \$mail_nok,
    'help'          => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mlc_task' );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'mlc_task', logger => $logger );

$audit->start($args);

unless ( substr($xml, 0, 1) eq '/' ) {
    $xml = $config->XMLDIR . '/' . $xml;
}

#
# initialize the task
#
my $task;
unless ( $task = MLC::Task->new( name => $name, template => $xml, sched_jobstream => $sched_js, config => $config, logger => $logger ) ) {
    $audit->end( $MLC::Task::errstr, 1 );
}

$task->run( move_logfiles => $move_logfiles, exclusive => 1 );

if ( $task->exitcode == 0 ) {
    $task->mail( address => $mail ) if $mail;
}
else {
    if ( $mail && $mail_nok ) {
        $mail .= ",$mail_nok";
    }
    elsif ( $mail_nok ) {
        $mail = $mail_nok;
    }
    $task->mail( address => $mail ) if $mail;
    $audit->end( $MLC::Task::errstr, $task->exitcode );
}

$audit->end($args, 0);

