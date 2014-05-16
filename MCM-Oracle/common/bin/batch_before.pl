#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Sybase2;
use Mx::Sybase::ResultSet;
use Mx::SQLLibrary;
use Mx::DBaudit;
use Mx::Util;
use File::Copy;
use File::Basename;
use Getopt::Long;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: batch_before.pl [ -n <name> ] [ -f <file1,file2,...> ] [ -t <table1,table2,...> ] [ -help ]

 -n <name>                    The name of the batch.
 -f <file1,file2,...>         The labels of files that will be produced (in the correct order).
 -t <table1,table2,...>       The labels of tables that will be produced (in the correct order).
 -help                        Display this text.
 
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
my ($batchname, $file_string, $table_string);
 
GetOptions(
    'n=s'      => \$batchname,
    'f=s'      => \$file_string,
    't=s'      => \$table_string,
    'help'     => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'batch_before' );

#
# check the environment variables
#
my $mx_session_id = $ENV{MXID};
unless ( $mx_session_id ) {
    $logger->logdie("environment variable MXID is not defined");
}
my $mx_desk = $ENV{MXDESK};
unless ( $mx_desk ) {
    $logger->logdie("environment variable MXDESK is not defined");
}

#
# check the arguments
#
unless ( $batchname ) {
    $logger->logdie('no report name specified');
}

unless ( $file_string || $table_string ) {
    $logger->logdie('no files or tables specified');
}

my @files = (); my @tables = ();

@files  = split ',', $file_string  if $file_string;
@tables = split ',', $table_string if $table_string;

my $nr_files  = @files;
my $nr_tables = @tables;

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
 
#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );
 
#
# open the Sybase connection
#
$sybase->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

my $query;
unless ( $query = $sql_library->query('batch_to_report') ) {
    $logger->logdie('query with as key report_file_tables cannot be retrieved from the library');
}

my $resultset;
unless ( $resultset = $sybase->query( query => $query, values => [ $batchname ] ) ) {
    $logger->logdie("cannot retrieve batch $batchname");
}

my @fields;
unless ( @fields = $resultset->next ) {
    $logger->logdie("cannot find batch $batchname");
}

my ( $reportname ) = @fields;

unless ( $query = $sql_library->query('report_file_tables') ) {
    $logger->logdie('query with as key report_file_tables cannot be retrieved from the library');
}

unless ( $resultset = $sybase->query( query => $query, values => [ $reportname ] ) ) {
    $logger->logdie("cannot retrieve report $reportname");
}

unless ( @fields = $resultset->next ) {
    $logger->logdie("cannot find report $reportname");
}

my ( $report_field, $dyntable0, $dyntable1, $dyntable2, $dyntable3, $dyntable4) = @fields;

my $report_template = $config->retrieve('REPORT_TEMPLATE_DIR') . '/' . lc( $report_field );
my $report_file     = $config->retrieve('MXENV_ROOT') . '/report2/' . lc( $report_field );

if ( -f $report_template ) {
    $logger->debug("report template $report_template found");
}
else {
    $logger->logdie("report template $report_template not found");
}

my $report_template_ph = $config->retrieve('REPORT_TEMPLATE_PH');

my %filehash = ();
my @ph = ();
my $count = 0;
foreach ( @files ) {
    my $ph = $report_template_ph;
    my $length = -1 * length( $count );
    substr( $ph, $length) = $count;
    push @ph, $ph;
    $filehash{$ph} = undef;
    $count++; 
}

my $nr_ph = Mx::Util->process_bintemplate( template => $report_template, cfghash => { substr( $report_template_ph, 0, -2 ) => undef }, dummy => 1, logger => $logger );

if ( $nr_files == $nr_ph ) {
    $logger->debug("number of files ($nr_files) matches number of placeholders ($nr_ph)");
}
else {
    $logger->logdie("number of files ($nr_files) doesn't match number of placeholders ($nr_ph)");
}

my %tablehash = ();
my @dyntables = ();
foreach my $dyntable ($dyntable0, $dyntable1, $dyntable2, $dyntable3, $dyntable4) {
    next unless $dyntable;
    push @dyntables, $dyntable;
    $tablehash{$dyntable} = undef;
}

my $nr_dyntables = @dyntables;

if ( $nr_tables == $nr_dyntables ) {
    $logger->debug("number of tables ($nr_tables) matches number of dyntables ($nr_dyntables)");
}
else {
    $logger->logdie("number of tables ($nr_tables) doesn't match number of dyntables ($nr_dyntables)");
}

my $report_output_dir = $config->retrieve('REPORT_OUTPUT_DIR');

my $table_prefix = 'REPBATCH#';
my $query_label;
if ( $mx_desk =~ /^PC_/ ) {
    $query_label   = 'pc_ref';
    $table_prefix .= 'PC_';
}
elsif ( $mx_desk =~ /^PLCC_/ ) {
    $query_label   = 'plcc_ref';
    $table_prefix .= 'PLCC_';
}
else {
    $query_label   = 'fo_desk_ref';
    $table_prefix .= 'FO_';
}

unless ( $query = $sql_library->query( $query_label ) ) {
    $logger->logdie('query with as key $query_label cannot be retrieved from the library');
}

unless ( $resultset = $sybase->query( query => $query, values => [ $mx_desk ] ) ) {
    $logger->logdie("cannot retrieve desk $mx_desk ");
}

unless ( @fields = $resultset->next ) {
    $logger->logdie("cannot find desk $mx_desk");
}

$table_prefix .= $fields[0] . '#';
$logger->debug("table prefix is $table_prefix");

#
# setup a connection to the monitoring database
#
my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

foreach my $label ( @files ) {
        my $ph   = shift @ph;
        my $path = $report_output_dir . '/' . basename( $ph );
        my $report_id = $db_audit->record_report_start( session_id => $mx_session_id, label => $label, path => $path, type => 'file' );
        $logger->debug("report id for file $label is $report_id");
        my $ph2 = $report_template_ph;
        my $length = -1 * length( $report_id );
        substr( $ph2, $length) = $report_id;
        $ph2 =~ s/x/0/g;
        $filehash{$ph} = $ph2;
        $path = $report_output_dir . '/' . basename( $ph2 );
        $db_audit->update_report( id => $report_id, path => $path );
}

foreach my $label ( @tables ) {
        my $dyntable  = shift @dyntables;
        my $tablename = $table_prefix . $dyntable . '.DBF'; 
        my $report_id = $db_audit->record_report_start( session_id => $mx_session_id, label => $label, table => $tablename, type => 'table' );
        $logger->debug("report id for table $label is $report_id");
        $tablehash{$dyntable} = $report_id;
        $tablename = $table_prefix . $report_id . '.DBF'; 
        $db_audit->update_report( id => $report_id, table => $tablename );
}

unless ( copy $report_template, $report_file ) {
    $logger->logdie("cannot copy $report_template to $report_file: $!");
}

unless ( Mx::Util->process_bintemplate( template => $report_file, cfghash => \%filehash, logger => $logger ) ) {
    $logger->logdie("cannot update placeholders in report file $report_file");
}

$logger->debug("placeholders replaced in report file $report_file");

unless ( $query = $sql_library->query('set_dyntable') ) {
    $logger->logdie('query with as key set_dyntable cannot be retrieved from the library');
}

while ( my ( $dyntable, $report_id ) = each %tablehash ) {
    my $tablename = $report_id;
    $sybase->do( statement => $query, values => [ $tablename, $dyntable ] );
    $logger->debug("table for dyntable $dyntable set to $tablename");
}

$db_audit->close();
