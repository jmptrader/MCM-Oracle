#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::EDW;


my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'get_edw' );

my $edw;
unless ( $edw = Mx::EDW->new( config => $config, logger => $logger ) ) {
    $logger->logdie("cannot create EDW object");
}

unless ( @ARGV ) {
    my $hash = $edw->hash;

	foreach my $key ( sort keys %{$hash} ) {
		printf "%-30s: %s\n", $key, $hash->{$key};
    }

	exit 0;
}

while ( my $variable = shift @ARGV ) {
    unless ( $edw->check_key( $variable ) ) {
		print "$variable does not exist\n";
		next;
    }

    print $edw->retrieve( $variable ) . "\n";
}
