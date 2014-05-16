#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Murex;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: dates.pl [ -fo ] [ -mo ] [ -bo ] [ -acc ] [ -ent ] [ -shift <number> ] [ -help ]

 -fo               Display only the Front Office dates.
 -bo               Display only the Back Office dates. 
 -mo               Display only the Middle Office dates.
 -ent              Display only the Entity dates.
 -acc              Display only the Accounting dates.
 -shift <number>   Signed integer used to specify an offset in the past or future.
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
my ($only_fo, $only_mo, $only_bo, $only_ent, $only_acc, $shift);

GetOptions(
    'fo'       => \$only_fo,
    'mo'       => \$only_mo,
    'bo'       => \$only_bo,
    'ent'      => \$only_ent,
    'acc'      => \$only_acc,
    'shift=i'  => \$shift,
    'help'     => \&usage,
);

my $all_dates = 1 unless $only_fo or $only_mo or $only_bo or $only_ent or $only_acc;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'dates' );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection (without specifying the database name)
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

#
# retrieve the Murex dates
#
if ( $all_dates or $only_fo ) {
    my @desks = Mx::Murex->fo_desks( sybase => $sybase, library => $sql_library, logger => $logger );

    print "\n";

    foreach my $label ( sort @desks ) {
        my  $date = Mx::Murex->date(type => 'FO', label => $label, shift => $shift, sybase => $sybase, library => $sql_library, config => $config, logger => $logger) || '' ;
        printf "%9s  %-20s %8s\n", "FO Date", $label, $date;
    }
}

if ( $all_dates or $only_mo ) {
    my @plccs = Mx::Murex->plc_centers( sybase => $sybase, library => $sql_library, logger => $logger );

    print "\n";

    foreach my $label ( sort @plccs ) {
        my  $date = Mx::Murex->date(type => 'MO', label => $label, shift => $shift, sybase => $sybase, library => $sql_library, config => $config, logger => $logger) || '';
        printf "%9s  %-20s %8s\n", "MO Date", $label, $date;
    }
}

if ( $all_dates or $only_bo ) {
    my @pcs = Mx::Murex->proc_centers( sybase => $sybase, library => $sql_library, logger => $logger );

    print "\n";

    foreach my $label ( sort @pcs ) {
        my  $date = Mx::Murex->date(type => 'BO', label => $label, shift => $shift, sybase => $sybase, library => $sql_library, config => $config, logger => $logger) || '';
        printf "%9s  %-20s %8s\n", "BO Date", $label, $date;
    }
}

if ( $all_dates or $only_ent ) {
    my @entities = Mx::Murex->entities( sybase => $sybase, library => $sql_library, logger => $logger );

    print "\n";

    foreach my $label ( sort @entities ) {
        my  $date = Mx::Murex->date(type => 'ENT', label => $label, shift => $shift, sybase => $sybase, library => $sql_library, config => $config, logger => $logger) || '';
        printf "%9s  %-20s %8s\n", "ENT Date", $label, $date;
    }
}

if ( $all_dates or $only_acc ) {
    my @entities = Mx::Murex->entities( sybase => $sybase, library => $sql_library, logger => $logger );

    print "\n";

    foreach my $label ( sort @entities ) {
        my  $date = Mx::Murex->date(type => 'ACC', label => $label, shift => $shift, sybase => $sybase, library => $sql_library, config => $config, logger => $logger) || '';
        printf "%9s  %-20s %8s\n", "ACC Date", $label, $date;
    }
}

print "\n";

$sybase->close;


