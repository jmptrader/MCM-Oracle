#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Account;
use Mx::Sybase;
use Mx::Sybase::Index;
use Mx::SQLLibrary;
use Mx::Alert;
use POSIX;
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'datamart_doubles' );


#
# create a pidfile
#

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
$sybase->open();

my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');

my $startup = 1;

my %existing_db_table_index_hash;


my ( $existing_indexes_ref, $existing_tables_ref ) = Mx::Sybase::Index->retrieve_all_existing(logger => $logger, config => $config, database_filter => $config->DB_REP);
	
foreach my $index ( @{$existing_indexes_ref} ) {
foreach my $db ( @{$index->database}){
	my $key = $db . ':' . $index->table . ':' . join(',', $index->columns);
	my $name = $index->name;
	if(exists $existing_db_table_index_hash{$key}){
		my $temp = $existing_db_table_index_hash{$key}->name;
		if($name ne $temp && $index->category eq 'KBC'){
		print "$key $name $temp\n";
	}
		}
	$existing_db_table_index_hash{$key} = $index;
}
}


