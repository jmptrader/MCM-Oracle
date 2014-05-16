#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::Sybase::Index2;

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'indexes' );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

$sybase->open();

#
# open the Sybase connection
#
my ( $array_indexes_ref, $hash_indexes_ref, $tables_ref ) = Mx::Sybase::Index2->retrieve_existing_indexes( sybase => $sybase, database => $config->DB_FIN, config => $config, logger => $logger );
my $kbc_indexes_ref = Mx::Sybase::Index2->retrieve_config_indexes( sybase => $sybase, database => $config->DB_FIN, config => $config, logger => $logger );
my $mx_indexes_ref  = Mx::Sybase::Index2->retrieve_murex_indexes( sybase => $sybase, config => $config, logger => $logger );

foreach my $index ( @{$kbc_indexes_ref} ) {
    $index->check( existing_indexes => $hash_indexes_ref, existing_tables => $tables_ref );
}

foreach my $index ( @{$mx_indexes_ref} ) {
    $index->check( existing_indexes => $hash_indexes_ref, existing_tables => $tables_ref );
}
