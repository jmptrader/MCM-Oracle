#!/usr/bin/env perl

use warnings;
use strict;

use DBI;
use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;

DBI->trace( 10 );

my $statement = 'insert into test_round2 (id, number) values ( ?, round( ?, 0 ) )';

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
my $account = Mx::Account->new( name => $config->MX_TSUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => 'mx_ont1_mon', username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

$sybase->do( statement => $statement, values => [ 1, 678956775654 ] );

