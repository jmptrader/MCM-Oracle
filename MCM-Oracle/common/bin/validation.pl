#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Context;
use Mx::Account;
use Mx::ScriptShell;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: validation.pl [ -intraday ] [ -mtl <number> ] [ -sched_js <stream> ] [ -mail <addresses> ] [ -mail_nok <addresses> ] [ -debug ] [ -help ]

 -intraday               Run a intraday validation.
 -mtl <number>           Maximum number of transactions to validate (MAX_TRN_LOCK).
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
my ($intraday, $mtl, $sched_js, $mail, $mail_nok, $debug);

GetOptions(
    'intraday'      => \$intraday,
    'mtl=i'         => \$mtl,
    'sched_js=s'    => \$sched_js,
    'mail=s'        => \$mail,
    'mail_nok=s'    => \$mail_nok,
    'debug!'        => \$debug,
    'help'          => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'validation' );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'validation', logger => $logger ); 

$audit->start($args);

my $script_name  = ( $intraday ) ? 'VALIDATION_INTRADAY' : 'VALIDATION';
my $context_name = ( $intraday ) ? 'intradayval' : 'bo';
my $extra_args   = ( $mtl ) ? "/MAX_TRN_LOCK:$mtl /MXPSVALWARNTYPE" : "/MXPSVALWARNTYPE";

#
# create the BO account
#
my $context_obj;
unless ( $context_obj = Mx::Context->new( name => $context_name, config => $config, logger => $logger ) ) {
    $audit->end("context $context_name cannot be found", 1);
}
my $mx_account;
unless ( $mx_account = $context_obj->account() ) {
    my $user = $context_obj->user();
    $audit->end("account $user cannot be found", 1);
}

my $template = $config->XMLDIR . '/validation.xml';

#
# initialize the script
#
my $script;
unless ( $script = Mx::ScriptShell->new( name => $script_name, template => $template, account => $mx_account, extra => $extra_args, sched_jobstream => $sched_js, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::ScriptShell::errstr, 1 );
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
    $audit->end( $Mx::ScriptShell::errstr, $script->exitcode );
}

$audit->end($args, 0);

