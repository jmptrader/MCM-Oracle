#!/usr/bin/env perl

use strict;
use warnings;

use BerkeleyDB;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: cat_db.pl <file>

 <file>       BerkeleyDB file that must be displayed.

EOT
;
    exit 1;
}

my $file = $ARGV[0];

unless ( $file ) {
    usage();
}

unless ( -f $file ) {
    print "cat_db.pl: cannot open $file\n";
    exit 2;
}

my %hash;
unless ( tie %hash, 'BerkeleyDB::Hash', -Filename => $file, -Flags => DB_RDONLY ) {
    print "$BerkeleyDB::Error\n";
    exit 3;
}

while ( my ($key, $value) = each %hash ) {
    print "$key: $value\n";
}

untie %hash;
