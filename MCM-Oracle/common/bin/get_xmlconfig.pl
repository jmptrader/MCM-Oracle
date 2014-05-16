#!/usr/bin/env perl

use strict;
use warnings;

use Mx::XMLConfig;

my $xmlconfig = Mx::XMLConfig->new();

unless ( @ARGV ) {
    foreach my $key ( sort $xmlconfig->get_keys ) {
        printf "%-45s: %s\n", $key, $xmlconfig->retrieve( $key );
    }
}

while ( my $variable = shift @ARGV ) {
    my $value = $xmlconfig->retrieve( $variable );

    print "$value\n";
}
