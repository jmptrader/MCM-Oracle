#!/usr/bin/env perl

use warnings;
use strict;

#use constant MAX_UNCOMPRESSED_SIZE => 1024;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::DBaudit;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Murex;
use Mx::Util;
use Mx::Report;
use Getopt::Long;
use File::Basename;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: There are 2 usages for this script.
       Either it is used to retrieve data from the database and format them as file or as an attachment to a mail
       or it will extract from the database just a numeric flag used as a return code (used especially in the con-
       text of controls for the EOD.
       Return code extraction mode: sql_extract.pl [ -name <library_tag> ] and the library tag has to start with "nf_"
       General extraction mode:     sql_extract.pl [ -name <library_tag> ] [ -output <csv file> ] 
                                                   [ -separator <separator> ] 
                                                   [ -quoted ] [ -yesterday ] [-library <path> ] [ -help ]
                                                   [ -def key1=value -def key2=value2 ... ]

 -name <library_tag>     identifier of the SQL portion in the SQL library
 -output <csv file>      csv file which will contain the result of the SQL query
 -separator <separator>  separator in the csv file (optional, default is comma)
 -quoted                 boolean indicating if all fields must be quoted
 -date                   one or more date offsets corresponding to __DATE<abs(offset)><P|F>__ placeholders in the sql (P=past, F=future)
 -library                Override the default SQL library set in the configuration file.
 -def key1=value1...     Corresponding value for placeholder __key1__ in the SQL query.
 -help                   Display this text.

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
my ($name, $file, $separator, $quoted, @date, $library_path, $no_file, %definitions);

GetOptions(
    'name=s'        => \$name,
    'output=s'      => \$file,
    'separator=s'   => \$separator,
    'quoted!'       => \$quoted,
    'date=i'        => \@date,
    'library=s'     => \$library_path,
    'def=s'         => \%definitions,
    'help'          => \&usage,
);

$no_file = ( substr( $name, 0, 1 ) eq 'nf_' ) ? 1 : 0;


#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sql_extract' );

#
# initialize auditing
#
my $audit   = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'sql_extract', logger => $logger );

$audit->start($args);

if ( ! $no_file && ! $file ) {
    $file = $name . '.csv';
}

if ( $file && substr( $file, 0, 1) ne '/' ) {
    $file = $config->retrieve('SQLDATADIR') . '/' . $file;
}

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->SQLUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 0, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

#
# setup the SQL library
#
$library_path ||= $config->retrieve('SQLLIBRARY');
unless ( substr( $library_path, 0, 1 ) eq '/' ) {
    $library_path = $config->retrieve('SQLDIR') . '/' . $library_path;
}
my $sql_library          = Mx::SQLLibrary->new( file => $library_path, logger => $logger );
my $std_sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

#
# retrieve the Murex FO dates
#

push( @date, 0 ); # always get current FO date
foreach my $offset( @date ){
    my $key = 'DATE'.( $offset ? ( abs($offset).( ( $offset > 0 ) ? 'F' : 'P' ) ) : '' ); # eg, for -1, $key becomes DATE1P
    $definitions{$key} = Mx::Murex->date(
        type => 'FO', shift => $offset, appl_type => 'EQD', sybase => $sybase, library => $std_sql_library, config => $config, logger => $logger
    );
}

#
# retrieve the query from the library
#
my $query;
unless ( $query = $sql_library->query($name, \%definitions) ) {
    $sybase->close();
    $audit->end("cannot retrieve sql with tag '$name' from the library", 1);
}

#
# make sure you run exclusively
#
my $process = Mx::Process->new( descriptor => $name, logger => $logger, config => $config );
unless ( $process->set_pidfile($0) ) {
    $sybase->close();
    $audit->end("not running exclusively", 1);
}

#
# connect to the monitoring database
#
my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config ) unless $no_file;

my $report_id = $db_audit->record_report_start( sql_tag => $name, sql_library => $library_path, type => 'file' ) unless $no_file;

#
# execute the query
#
my ($result, $names);
unless ( ($result, $names) = $sybase->composite_query( query => $query, quiet => 1 ) ) {
    $sybase->close();
    $db_audit->close() unless $no_file;
    $process->remove_pidfile();
    $audit->end('sql query failed', 1);
}

$sybase->close();

$process->remove_pidfile();

my $rc = 0;
if ( $no_file ) {
    $rc = $result->[0][0];
}
else {
    #
    # create the csv file
    #
    unless ( $sybase->to_csv( rows => $result, names => $names, file => $file, separator => $separator, quoted => $quoted ) ) {
        $db_audit->close();
        $audit->end('creation of csv file failed', 1);
    }

    my $report = Mx::Report->new( id => $report_id, file => $file, config => $config, logger => $logger );

    $report->archive();

    my $txt_size = $report->txt_size();
    my $nr_lines = $report->nr_lines();
    $db_audit->record_report_end( report_id => $report_id, txt_size => $txt_size, nr_lines => $nr_lines, txt_path => $file );

    $db_audit->close();

    #
    # if the csv file is too big, compress it first
    #
    #my $size = -s $file;
    #if ( $size > MAX_UNCOMPRESSED_SIZE ) {
    #    $logger->debug("filesize is $size, compressing csv file");
    #    if ( Mx::Util->compress( sourcefile => $file, targetfile => "$file.gz", erase => 1, config => $config, logger => $logger ) ) {
    #        $file .= '.gz';
    #        $size = -s $file;
    #        $logger->debug("file compressed, new size is $size");
    #    }
    #    else {
    #        $audit->end("unable to compress $file", 1);
    #    }
    #}

    #
    # if necessary, mail the csv file
    #
    #if ( $mail ) {
    #    my $subject = $name;
    #    my $body    = "Please find your data attached.\n\nGenerated by $0"; 
    #    my $message = Mx::Mail->new( to => $mail, subject => $subject, body => $body, file => $file, logger => $logger);
    #   $message->send();
    #}
    
    print $report_id, "\n";
}

$audit->end($args, $rc);
