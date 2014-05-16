#!/usr/bin/env perl

use IO::Uncompress::Gunzip qw(gunzip);

my $file = '/shared/.tmp/brol';

my $output;
gunzip $file => \$output;

print $output;
