#!/usr/bin/env perl

use strict;
use warnings;

use XML::Simple;


my $file = $ARGV[0] or die "no file specified";

my $xs = XML::Simple->new();

my $ref = $xs->XMLin($file, ForceArray => 1, KeepRoot => 1);

print $xs->XMLout($ref, KeepRoot => 1);
