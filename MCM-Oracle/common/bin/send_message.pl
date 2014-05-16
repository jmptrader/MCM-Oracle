#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Message;
use Mx::DBaudit;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: send_message.pl [ -type <user|env> ] [ -dest <destination> ] [ -prio <priority> ] [ -valid <seconds> ] [ -text <message> ] [ -help ]

 -type        Type of the message: individual user ('user') or complete environment ('env').
 -dest        Name of the user or environment.
 -prio        Priority of the message: 'low', 'medium', 'high' or 'critical'. Default is 'low'.
 -valid       Number of seconds the message is displayed. -1 means forever (default).
 -text        Actual message.
 -help        Display this text.

EOT
;
    exit;
}

my ($type, $destination, $priority, $validity, $text);

GetOptions(
    'type=s'       => \$type,
    'dest=s'       => \$destination,
    'prio=s'       => \$priority,
    'valid=s'      => \$validity,
    'text=s'       => \$text,
    'help'         => \&usage
);

unless ( $type && $destination && $text ) {
    usage();
}

my $config = Mx::Config->new();

my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'send_message' );

my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

unless ( $type eq $Mx::Message::TYPE_USER or $type eq $Mx::Message::TYPE_ENVIRONMENT ) {
    $logger->logdie("wrong message type: $type");
}

$priority ||= 'low';

unless ( $priority eq $Mx::Message::PRIO_LOW or $priority eq $Mx::Message::PRIO_MEDIUM or $priority eq $Mx::Message::PRIO_HIGH or $priority eq $Mx::Message::PRIO_CRITICAL ) {
    $logger->logdie("wrong message priority: $priority");
}

my $message = Mx::Message->new(
  type        => $type,
  destination => $destination,
  priority    => $priority,
  validity    => $validity || -1,
  message     => $text,
  db_audit    => $db_audit,
  logger      => $logger
);

$message->send;

