#!/usr/bin/env perl

use IO::Compress::Deflate qw(deflate);

my $inputfile  = $ARGV[0];
my $outputfile = $ARGV[1];

open IN,  "<$inputfile";
open OUT, ">$outputfile";

my $cleartext;
while ( <IN> ) {
    $cleartext .= $_;
}

close(IN);

my $compressed_text;
deflate \$cleartext => \$compressed_text;

print OUT $compressed_text;

close(OUT);
