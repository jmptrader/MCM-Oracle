#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Oracle;
use Data::Dumper;

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'bcp' );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MON_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $oracle  = Mx::Oracle->new( username => $account->name, password => $account->password, database => $config->DB_MON, config => $config, logger => $logger );

#
# open the Sybase connection
#
$oracle->open();

$oracle->bcp_in( table => 'sessions', file => '/var/tmp/brol.csv' );

$oracle->close();


