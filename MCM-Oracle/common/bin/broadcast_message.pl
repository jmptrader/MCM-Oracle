#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Ant;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: broadcast_message.pl [ -m <message> ] [ -help ]

 -m <message>  Message to broadcast.
 -help         Display this text.

EOT
;
    exit;
}

my ($message);

GetOptions(
    'm=s'     => \$message,
    'help'    => \&usage,
);

unless ( $message ) {
    usage;
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'broadcast_message' );

$logger->info("broadcasting the message '$message'");

my $template = $config->XMLDIR . '/broadcast_message.xml';

my $script;
unless ( $script = Mx::Ant->new( name => 'broadcast_message', template => $template, target => 'broadcastMessage', cfghash => { __MESSAGE__ => $message }, config => $config, logger => $logger, no_extra_logdir => 1, no_audit => 1 ) ) {
    $logger->error("ant session could not be initialized");
    exit 1;
}

$script->run();
 
unless ( $script->exitcode == 0 ) {
   $logger->error("ant session failed");
   exit 1;
}

exit 0;

