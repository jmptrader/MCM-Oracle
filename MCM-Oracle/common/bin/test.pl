#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Service;
use Mx::Secondary;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'test' );

#
# connect to the secondary monitor (if there is one)
#
my $soap_handle1 = Mx::Secondary->handle( instance => 1, config => $config, logger => $logger );
my $soap_handle2 = Mx::Secondary->handle( instance => 2, config => $config, logger => $logger );
my $soap_handle3 = Mx::Secondary->handle( instance => 3, config => $config, logger => $logger );

#
# get a list of all the configured services
#
my @services = Mx::Service->list(config => $config, logger => $logger);

#
# get the current status of all services
#
my @local_services = (); my @remote_services1 = (); my @remote_names1 = (); my @remote_services2 = (); my @remote_names2 = (); my @remote_services3 = (); my @remote_names3 = ();
foreach my $service ( @services ) {
    if ( $service->location eq 'primary' ) {
        push @local_services, $service;
    }
    elsif ( $service->location eq 'secondary:1' ) {
        push @remote_names1, $service->name;
    }
    elsif ( $service->location eq 'secondary:2' ) {
        push @remote_names2, $service->name;
    }
    elsif ( $service->location eq 'secondary:3' ) {
        push @remote_names3, $service->name;
    }
}

Mx::Service->update( list => [ @local_services ] ) if ( @local_services );
@remote_services1 = $soap_handle1->mservice( names => \@remote_names1 )->paramsall  if ( @remote_names1 );
@remote_services2 = $soap_handle2->mservice( names => \@remote_names2 )->paramsall  if ( @remote_names2 );
@remote_services3 = $soap_handle3->mservice( names => \@remote_names3 )->paramsall  if ( @remote_names3 );
@services = ( @local_services, @remote_services1, @remote_services2, @remote_services3 );

my @processes;
foreach my $service ( @services ) {
    push @processes, $service->processes;
}

foreach my $process ( @processes ) {
    printf "%s:%s: %d\n", $process->hostname, $process->label, $process->pid;
}
