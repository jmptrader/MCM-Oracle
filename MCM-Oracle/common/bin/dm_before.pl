#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Semaphore;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'dm_before' );


my $session_id;
unless ( $session_id = $ENV{MXID} ) {
    $logger->logdie("environment variable MXID does not exist");
}

my $semaphore;
unless ( $semaphore = Mx::Semaphore->new( key => $session_id, type => $Mx::Semaphore::TYPE_COUNT, logger => $logger, config => $config ) ) {
    $logger->logdie("unable to locate semaphore '$session_id'");
}

unless ( $semaphore->external_release( cleanup => 1 ) ) {
    $logger->logdie("unable to release semaphore '$session_id'");
}

exit 0;
