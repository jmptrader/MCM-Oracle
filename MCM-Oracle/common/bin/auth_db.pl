#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Auth::DB;
use Mx::Auth::Replicator;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: auth_db.pl [ -export ] [ -import ] [ -dir <directory> ] [ -help ]
 
 -export           Export the authorization database to file.
 -import           Import the authorization database from file.
 -dir <directory>  Directory where the files should be written or read from.
 -help             Display this text.
 
EOT
;
    exit;
}
 
my ($do_export, $do_import, $directory);
 
GetOptions(
    'export'  => \$do_export,
    'import'  => \$do_import,
    'dir=s'   => \$directory,
    'help'    => \&usage,
);

unless ( $do_export or $do_import ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'auth_db' );

my $replicator_type = $config->AUTH_REPLICATOR_TYPE;

if ( $do_export && $replicator_type ne $Mx::Auth::Replicator::TYPE_MASTER ) {
    $logger->logdie("an export can only be performed on a replicator master");
}

if ( $do_import && $replicator_type ne $Mx::Auth::Replicator::TYPE_SLAVE ) {
    $logger->logdie("an import can only be performed on a replicator slave");
}

$directory = $directory || $config->DUMPDIR;

my $auth_db = Mx::Auth::DB->new( logger => $logger, config => $config );

if ( $do_export ) {
    $auth_db->export_tables( directory => $directory );
}
elsif ( $do_import ) {
    $auth_db->import_tables( directory => $directory );
}
