#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Sybase::Index;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: refresh_indexes.pl [ -force ] [ -help ]

 -force                    Start the refresh.
 -help                     Display this text.

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
my ( $force );

GetOptions(
    'force!'        => \$force,
    'help'          => \&usage,
);

unless ( $force ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'refresh_indexes' );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

Mx::Sybase::Index->refresh_indexes( sybase => $sybase, library => $sql_library, config => $config, logger => $logger );

$sybase->close();
