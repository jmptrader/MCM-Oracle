#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: outputfiles.pl [ -a ] [ -id <nr> ] [ -help ]

 -a         Indicate that the ID is of a autobalance session.
 -id <nr>   ID of the session.
 -help      Display this text.

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
my ($autobalance, $id);

GetOptions(
    'a'        => \$autobalance,
    'id=i'     => \$id,
    'help'     => \&usage,
);

exit unless $id;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'outputfiles' );

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

my @report_ids;
if ( $autobalance ) {
    @report_ids = $db_audit->retrieve_linked_reports( ab_session_id => $id );
}
else {
    @report_ids = $db_audit->retrieve_linked_reports( session_id => $id );
}

foreach my $report_id ( @report_ids ) {
    my $report = $db_audit->retrieve_report( id => $report_id );
    printf "%d:%s\n", $report_id, $report->[6];
}

$db_audit->close();

