#!/usr/bin/env perl

use XML::XPath;

my $file = $ARGV[0];

my $xml;
open FH, $file;
while ( <FH> ) {
    $xml .= $_;
}
close( FH );

my $xp = XML::XPath->new( xml => $xml );

my $unit;
my $unit_set = $xp->find('/Script/Items/Item/Unit');

if ( $unit_set->size() == 1 ) {
    $unit = $unit_set->get_node(1)->string_value;
}

print $unit, "\n";
