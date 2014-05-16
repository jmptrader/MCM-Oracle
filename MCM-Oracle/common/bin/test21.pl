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
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'job_info' );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $oracle  = Mx::Oracle->new( username => $account->name, password => $account->password, database => $config->DB_FIN, config => $config, logger => $logger );

my $query = "select M_IDJOB, M_STATUS, M_REF_DATA from ACT_JOB_DBF where to_char(M_DATE, 'YYYYMMDD') = ? and M_PID = ? and rtrim(M_BATCH) = ?";

#
# open the Sybase connection
#
$oracle->open();

my $result = $oracle->query( query => $query, values => [ '20140128', 24683, 'BF_DMP_TRADE' ]  );

my @row = $result->next;

print "@row\n";


$oracle->close();


