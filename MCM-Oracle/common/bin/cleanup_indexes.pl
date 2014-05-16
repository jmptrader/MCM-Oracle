#!/usr/bin/env perl

use warnings;
use strict; 

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::Sybase::Index;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: cleanup_indexes.pl [ -help ]

 -help        Display this text

EOT
;
    exit;
}


#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#

GetOptions(
    'help!'      => \&usage,
);


#
# read the configuration files
#
my $config = Mx::Config->new();
 
#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'cleanup_indexes' );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
 
#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

#
# open the Sybase connection
#
$sybase->open();

my $result = $sybase->query( query => 'select distinct(M_TABNAME) from MUREXDB.RDBMXNDX_DBF' );

foreach my $row ( @{$result} ) {
    my $table = $row->[0];
    $table .= '_DBF';

    if ( my $result2 = $sybase->query( query => 'select * from sysobjects where name = ?', values => [ $table ] ) ) {
        unless ( @{$result2} ) {
            print "table $table does not exist\n";
        }
    }
}



$sybase->close();

exit 0;

