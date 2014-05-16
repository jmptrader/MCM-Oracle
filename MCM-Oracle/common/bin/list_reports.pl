#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Report;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: list_reports.pl -i <session_id> [ -s <separator> ] [ -help ]
 
 -i <session_id>    ID of the session for which the reports must be retrieved.
 -s <separator>     Separator to use between the label and the path or tablename (default is :)
 -help              Display this text.
 
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
my ($session_id, $separator);
 
GetOptions(
    'i=i'       => \$session_id,
    's=s'       => \$separator,
    'help'      => \&usage,
);

unless ( $session_id ) {
    usage();
}

$separator ||= ':';
 
#
# read the configuration files
#
my $config = Mx::Config->new();
 
#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'list_reports' );

#
# connect to the monitoring database
#
my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );


my %reports = Mx::Report->retrieve( session_id => $session_id, db_audit => $db_audit, logger => $logger );

while ( my ( $label, $report ) = each %reports ) {
    my $where = ( $report->type eq 'file' ) ? $report->path : $report->tablename; 
    printf "%s%s%s\n", $label, $separator, $where;
}
