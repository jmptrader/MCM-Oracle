#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase2;
use IO::Uncompress::Gunzip qw(gunzip);
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: classify_statements.pl [ -full ] [ -help ]

 -full             Recompute all SQL tags.
 -help             Display this text.

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
my ( $do_full );

GetOptions(
    'full!'  => \$do_full,
    'help'   => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'classify_statements' );

if ( $do_full ) {
    $logger->info("starting full classification of historical SQL statements");
}
else {
    $logger->info("starting classification of historical SQL statements");
}

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MONUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->MONDB_NAME, username => $account->name, password => $account->password, error_handler => 0, logger => $logger, config => $config );

#
# open the Sybase connection
#
unless ( $sybase->open() ) {
    $logger->logdie("unable to connect to monitoring database");
}

my $query = 'select id, sql_text from statements';

unless ( $do_full ) {
    $query .= " where sql_tag = ''";
}

my $statement = 'update statements set sql_tag = ? where id = ?';

my $result = $sybase->query( query => $query, delayed => 1 );

my $count = 0;
while ( my ( $id, $compressed_sql_text ) = $result->next ) {
    my $sql_text;
    gunzip \$compressed_sql_text => \$sql_text;

    my $sql_tag = Mx::Sybase2->sql_tag( $sql_text );

    $sybase->do( statement => $statement, values => [ $sql_tag, $id ] );

    $count++;

    if ( $count % 1000 == 0 ) {
        $logger->debug("processed $count statements");
    }
}

$sybase->close();

$logger->info("classification finished. processed $count statements");
