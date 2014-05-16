#!/usr/bin/env perl

use strict;
use warnings;

use IO::File;
use Mx::Env;
use Mx::Config;

my $config = Mx::Config->new();

my $xml_file = Mx::Config->configfile();
$xml_file =~ s/\.cfg$/.xml/;

my $fh;
unless ( $fh = IO::File->new( $xml_file, '>' ) ) {
    die "cannot open $xml_file: $!\n";
}

print $fh $config->to_xml;

$fh->close;

