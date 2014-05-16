#!/usr/bin/env perl

use warnings;
use strict;

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
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'test_oracle' );

my $account = Mx::Account->new( name => $config->MON_DBUSER, config => $config, logger => $logger );

my $oracle  = Mx::Oracle->new( database => $config->DB_MON, username => $account->name, password => $account->password, config => $config, logger => $logger );

$oracle->open();

#print $oracle->table_owner( table => 'TRN_HDR_DBF' );



#my @tables = $oracle->all_tables();

foreach my $table ( 'USER_GROUP' ) {
  my @columns = $oracle->table_column_info( table => $table );
  print Dumper ( \@columns );
#   print $oracle->table_ddl( table => $table );
}

$oracle->close();
