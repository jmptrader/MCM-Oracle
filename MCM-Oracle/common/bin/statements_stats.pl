#!/usr/bin/env perl

use warnings;
use strict;


use Mx::Env;
use Mx::Config;
use Mx::Log;
use Getopt::Long;
use Mx::Account;
use Mx::PerlScript;
use Mx::Sybase2;
use Mx::Scheduler;


#---------#
sub usage {
#---------#

  print <<EOT

  Usage: statements_stats.pl -sched_js <jobstream>
    -sched_js <jobstream>    TWS jobstream name
    -help                    Display this text
EOT
;
  exit;
}


# 
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# get the script arguments
#
my ( $sched_js );

GetOptions(
    'help'           => \&usage,
    'sched_js=s'     => \$sched_js,
);

unless ( $sched_js ) {
    usage();
};

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'statements_stats' );


#
# create historical script
#
my $script = Mx::PerlScript->new( logger => $logger, config => $config );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
    
#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->MONDB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLDIR . '/statements_stats.sql', logger => $logger );


# open sybase connection
unless ( $sybase->open() ) {
    $logger->info( 'Open sybase connection failed' );
    return -1;
};

my $query = $sql_library->query( "statements_stats" );

my $query_rv = $sybase->query( query => $query, quiet => 0 ) ;

$sybase->close();

$logger->info( "All update queries were succesful") ;

$script->finish();


