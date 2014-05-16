#!/usr/bin/env perl

use XML::XPath;
use Data::Dumper;
use Mx::Util;

my $file = $ARGV[0];

my $xml;
open FH, $file;
while ( <FH> ) {
    $xml .= $_;
}
close( FH );

my $xp = XML::XPath->new( xml => $xml );

my @exceptions;
my $exception_set = $xp->find('/LogRoot/MXException');

foreach my $exception ( $exception_set->get_nodelist ) {
    my $level; my $description;
    foreach my $child ( $exception->getChildNodes ) {
        if ( $child->getName() eq 'Level' ) {
            $level = $child->string_value;
        }
        elsif ( $child->getName() eq 'Description' ) {
            $description = $child->string_value;
        }
    }

    push @exceptions, { level => $level, description => $description };
}

print Dumper( @exceptions );

