#!/usr/bin/env perl

use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Secondary;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'secondary' );

my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

foreach my $handle ( @handles ) {
    my %info = $handle->soaphandle->status->paramsall;

    printf "%-3d %-10s %8s  %s\n", $handle->instance, $handle->short_hostname, $info{pid}, scalar( localtime( $info{starttime} ) );
}
