#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Service;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: access.pl [ -enable ] [ -disable ] [ -list ]

 -enable       Enable access to Murex.
 -disable      Disable access to Murex.
 -list         Show current access status.
 -help         Display this text.

EOT
;
    exit;
}

#
# process the commandline arguments
#
my ($enable, $disable, $list);

GetOptions(
    'enable'       => \$enable,
    'disable'      => \$disable,
    'list'         => \$list,
    'help'         => \&usage,
);

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new(
  directory => $config->LOGDIR,
  keyword   => 'access',
);

if ( $enable ) {
    if ( Mx::Service->enable_access($config, $logger) ) {
        print "access is enabled\n";
        exit 0;
    }
    else {
        print "access cannot be enabled\n";
        exit 1;
    }
}

if ( $disable ) {
    if ( Mx::Service->disable_access($config, $logger) ) {
        print "access is disabled\n";
        exit 0;
    }
    else {
        print "access cannot be disabled\n";
        exit 1;
    }
}

if ( $list ) {
    if ( Mx::Service->check_access($config, $logger) ) {
        print "access is enabled\n";
    }
    else {
        print "access is disabled\n";
    }
}
