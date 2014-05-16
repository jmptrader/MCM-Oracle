#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Alert;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'alert' );

my $alert = Mx::Alert->new( name => 'sybase_entitlement', config => $config, logger => $logger );

my $id = $alert->trigger( level => $Mx::Alert::LEVEL_WARNING, values => [ 203 ], item => 'blabla' );

#my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

#Mx::Alert->acknowledge_alert( id => $id, db_audit => $db_audit );
