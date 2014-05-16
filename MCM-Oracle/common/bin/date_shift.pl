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

Usage: shift_date.pl [ -date <date> ] [ -shift <number> ] [ -calendar <calendar> ] [ -help ]

 -date <date>           Date to be shifted in the format YYYYMMDD.
 -shift <number>        Signed integer used to specify an offset in the past or future.
 -calendar <calendar>   Label of the Murex calendar to use.
 -help                  Display this text.

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
my ($date, $shift, $calendar);

GetOptions(
    'date=s'     => \$date,
    'calendar=s' => \$calendar,
    'shift=i'    => \$shift,
    'help'       => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'date_shift' );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection
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

my $new_date = Mx::Murex->date_shift( date => $date, shift => $shift, calendar => $calendar, library => $sql_library, sybase => $sybase, logger => $logger );

print "$new_date\n";

$sybase->close;


