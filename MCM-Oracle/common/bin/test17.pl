#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Config;
use Mx::Log;
use Mx::Linux::Sysperfstat;

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sysperf' );

my $sysperf = Mx::Linux::Sysperfstat->new( logger => $logger, config => $config );

while ( 1 ) {
    $sysperf->refresh();

    printf "user cpu:    %f\n", $sysperf->ucpu_user;
    printf "system cpu:  %f\n", $sysperf->ucpu_system;
    printf "idle cpu:    %f\n", $sysperf->ucpu_idle;
    printf "iowait cpu:  %f\n", $sysperf->ucpu_iowait;
    printf "memory free: %f\n", $sysperf->umem;
    printf "swap free:   %f\n", $sysperf->uswap;
    printf "disk read:   %f\n", $sysperf->udsk_read;
    printf "disk write:  %f\n", $sysperf->udsk_write;
    printf "net receive: %f\n", $sysperf->unet_rx;
    printf "net send:    %f\n", $sysperf->unet_tx;
    printf "load:        %f\n", $sysperf->load;
    print "\n";

    sleep 5;
}

