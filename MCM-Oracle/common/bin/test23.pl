#!/usr/bin/env perl

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::ProcScript;

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'procscript' );


my $xmlfile = $ARGV[0];

my $procscript = Mx::ProcScript->new( xml => $xmlfile, logger => $logger );

my @procscripts = $procscript->split();

foreach my $script ( @procscripts ) {
    printf "%s:%s:%s:%s\n", $script->name, $script->item_name, $script->item_label, $script->unit;
}
