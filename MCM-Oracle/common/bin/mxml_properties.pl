#!/usr/bin/env perl

use warnings;
use strict; 

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Murex;
use Mx::DBaudit;
use Mx::MxML::Node;
use Getopt::Long;

my @PROPERTIES = qw( MXENV PILLAR EGATE_DISABLED EGATE_DISABLED_CG AA_DUMP_ENABLED BOM_ACTIVE EXP_REFRESH_DISABLED );

#---------#
sub usage {
#---------#
    print <<EOT

Usage: mxml_properties.pl [ -create ] [ -property <key> -value <value> ] [ -help ]

 -create               Create the MxML property table.
 -property <property>  Property that must be updated.
 -value <value>        Value to use for the update.
 -help                 Display this text

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
my ($create, $property, $value);

GetOptions(
    'create!'    => \$create,
    'property=s' => \$property,
    'value=s'    => \$value,
    'help!'      => \&usage,
);

unless ( $create || ( $property && $value ) ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();
 
#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mxml_properties' );

$logger->info("refreshing/updating MxML property table");

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
 
#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

if ( $create ) {
    my $create_statement;
    unless ( $create_statement = $sql_library->query('mxml_property_table') ) {
        $logger->logdie('query with as key mxml_property_table cannot be retrieved from the library');
    }

    $sybase->composite_do( statement => $create_statement );

    my $insert_statement;
    unless ( $insert_statement = $sql_library->query('mxml_add_property') ) {
        $logger->logdie('query with as key mxml_add_property cannot be retrieved from the library');
    }

    foreach my $property ( @PROPERTIES ) {
        my $value = $config->retrieve( $property, 1 );

        unless ( $value ) {
            $logger->info("skipping property '$property' as it is not defined");
            next;
        }

        $sybase->do( statement => $insert_statement, values => [ $property, $value ] );

        $logger->info("added property '$property', value '$value'");
    }

    my @entity_sets = Mx::Murex->entity_sets( sybase => $sybase, library => $sql_library, config => $config, logger => $logger );

    foreach my $entity_set ( @entity_sets ) {
        my ( $entity ) = $entity_set =~ /^ES_(\w+)$/;

        my $property = 'CLOSEDOWN_PENDING_' . $entity;
        my $value    = 'N';

        $sybase->do( statement => $insert_statement, values => [ $property, $value ] );

        $logger->info("added property '$property', value '$value'");
    }

    if ( my $node = Mx::MxML::Node->retrieve( taskname => 'p1exg_IMM_createValidationReport', nodename => 'Document Generated', db_audit => $db_audit, config => $config, logger => $logger ) ) {
        my $property = 'p1exg_IMM_createValidationReport';
        my $value    = $node->id;

        $sybase->do( statement => $insert_statement, values => [ $property, $value ] );

        $logger->info("added property '$property', value '$value'");
    }

    if ( my $node = Mx::MxML::Node->retrieve( taskname => 'p1exg_IMM_validationQueue', nodename => 'Input', db_audit => $db_audit, config => $config, logger => $logger ) ) {
        my $property = 'p1exg_IMM_validationQueue';
        my $value    = $node->id;

        $sybase->do( statement => $insert_statement, values => [ $property, $value ] );

        $logger->info("added property '$property', value '$value'");
    }
}

if ( $property && $value ) {
    my $update_statement;
    unless ( $update_statement = $sql_library->query('mxml_update_property') ) {
        $logger->logdie('query with as key mxml_update_property cannot be retrieved from the library');
    }

    $sybase->do( statement => $update_statement, values => [ $value, $property ] );

    $logger->info("updated property '$property', value '$value'");
}

$logger->info("MxML property table is refreshed/updated");

$sybase->close();

$db_audit->close();

exit 0;


