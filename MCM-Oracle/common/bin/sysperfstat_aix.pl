#!/usr/bin/env perl

$| = 1;

my $poll_interval = $ARGV[0] || 5;

open CMD, "/usr/bin/vmstat $poll_interval|" or die "cannot launch vmstat: $!";

while ( <CMD> ) {
    if ( /^\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([.0-9]+)\s+([.0-9]+)$/ ) {
        my $timestamp         = time();
        my $runqueue          = $1;
        my $scanrate          = $2;
        my $cpu_user          = $3;
        my $cpu_system        = $4;
        my $cpu_idle          = $5;
        my $cpu_wait          = $6;
        my $physical_procs    = $7;
        my $entitled_capacity = $8;
        printf "%d:%d:%d:%d:%d:%d:%d:%s\n", $timestamp, $runqueue, $scanrate, $cpu_user, $cpu_system, $cpu_idle, $cpu_wait, $entitled_capacity;
    }
}

close(CMD);
