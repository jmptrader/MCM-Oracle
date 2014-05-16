#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sybase_kill' );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, database => $config->MONDB_NAME, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

my $rc = $sybase->do( statement => 'update index statistics sessions' );

print "rc: $rc\n";

$sybase->close();

