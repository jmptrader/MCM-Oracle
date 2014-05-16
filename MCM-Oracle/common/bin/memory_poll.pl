#!/usr/bin/env perl

use strict;
use warnings;

my ($pid, $interval) = @ARGV;

while ( 1 ) {
    my $timestamp = time();

    open CMD, "/usr/bin/pmap -x $pid|";
    my @output = <CMD>;
    close(CMD);
    
    my $line = pop @output;
    if ( $line =~ /^total Kb\s+(\d+)\s+(\d+)\s+(\d+)\s+/ ) {
        print "$timestamp:$1:$2:$3\n";
    }

    sleep $interval;
}
