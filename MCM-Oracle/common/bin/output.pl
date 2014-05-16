#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::DBaudit;
use Mx::Report;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: output.pl [ -c <command> ] [ -help ]

 -c <command>                        Execute this command with the file as argument.
 -help                               Display this text.

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
my ($command);

GetOptions(
    'c=s'      => \$command,
    'help'     => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'output' );

#
# initialize auditing
#
my $audit  = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'output', logger => $logger );

$audit->start($args);

my $db_audit; my @report_ids = ();
if ( my $session_id = $ENV{MXID} ) {
    $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );
    my @report_ids = $db_audit->get_report_ids( session_id => $session_id );
    unless ( @report_ids ) {
        $audit->end("no report found in the database belonging to session id $session_id - check output_before.pl", 1);
    }
}

my @reports = ();
foreach my $report_id ( @report_ids ) {
    my $result = $db_audit->retrieve_report( id => $report_id );
    my ( $table, $file, $type ) = @result->[6,7,11];
    my $report;
    if ( $type eq 'file' ) {
        unless ( $report = Mx::Report->new( id => $report_id, file => $file, scriptname => $ENV{MXSCRIPTNAME}, username => $ENV{MXRUSER}, config => $config, logger => $logger ) ) {
            $audit->end("report initialisation failed", 1);
        }
    }
    elsif ( $type eq 'table' ) {
        unless ( $report = Mx::TableReport->new( id => $report_id, table => $table, scriptname => $ENV{MXSCRIPTNAME}, username => $ENV{MXRUSER}, config => $config, logger => $logger ) ) {
            $audit->end("report initialisation failed", 1);
        }
    }

    push @reports, $report;
}

foreach my $report ( @reports ) {
    my $report_id  = $report->id;
    my $size       = $report->size;
    my $nr_records = $report->nr_records;
    $db_audit->record_report_end( report_id => $report_id, size => $size, nr_records => $nr_records, command  => $command );
}

#
# make an archive copy of the report
#
#$report->archive();

#
# if a command was specified, execute this command
#
if ( $command ) {
    unless ( $report->execute( command => $command ) ) {
        $audit->end("command failed", 1);
    }
}

$db_audit->close();

$audit->end($args, 0);

