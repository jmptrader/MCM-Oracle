#!/usr/bin/env perl

use Mx::Config;

my $file = $ARGV[0];

my $config = Mx::Config->new();

$config->dump( $file );
