#!/usr/bin/env perl

use strict;

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use IO::File;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: schema.pl [ -db <database> ] [ -o <outputfile> ] [ -help ]

 -db <database>    Name of the database to examine. Default is the monitoring database.
 -o <outputfile>   Name of the outputfile. Default is schema_<database>.csv
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
my ( $database, $outputfile );

GetOptions(
    'db=s'  => \$database,
    'o=s'   => \$outputfile,
    'help'  => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'schema' );

$database = $database || $config->MONDB_NAME;
$logger->info("database to examine is $database");

$outputfile = $outputfile || 'schema_' . $database . '.csv';

unless ( substr( $outputfile, 0, 1 ) eq '/' ) {
    $outputfile = $config->SHAREDDIR . '/' . $outputfile;
}

my $fh;
if ( $fh = IO::File->new( $outputfile, '>' ) ) {
    $logger->info("outputfile is $outputfile");
}
else {
    $logger->logdie("cannot open $outputfile: $!");
}

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $database, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

my @tables = $sybase->all_tables( database => $database );

foreach my $table ( sort @tables ) {
    if ( my @columns = $sybase->table_column_info( table => $table, database => $database ) ) {
        foreach my $column ( sort { $a->{name} cmp $b->{name} } @columns ) {
            printf $fh "%s:%s:%s:%d:%d\n", $table, $column->{name}, $column->{type}, $column->{length}, $column->{precision};
        }
    }

    if ( my @indexes = $sybase->table_index_info( table => $table, database => $database ) ) {
        foreach my $index ( sort { $a->{name} cmp $b->{name} } @indexes ) {
            printf $fh "*%s:%s:%s:%s\n", $table, $index->{name}, $index->{column}, $index->{type};
        }
    }
}

$fh->close;
$sybase->close;

