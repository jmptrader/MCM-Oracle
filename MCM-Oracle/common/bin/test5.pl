#!/usr/bin/env perl

use Mx::Config;
use Mx::Log;
use Mx::FileSync;
use Data::Dumper;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'test5' );

my $target = $ARGV[0];

my $filesync = Mx::FileSync->new( target => $target, recursive => 1, logger => $logger );

$filesync->analyze();


print Dumper( $filesync );
