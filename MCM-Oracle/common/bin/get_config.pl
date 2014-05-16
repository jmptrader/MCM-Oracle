#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;

my $SEPARATOR = "\n";

my $config = Mx::Config->new();

while ( my $variable = shift @ARGV ) {
    my $value = $config->retrieve( $variable ); 

    if ( ref( $value ) eq 'ARRAY' ) {
        $value = join $SEPARATOR, @{ $value };
    }

    print "$value\n";
}
