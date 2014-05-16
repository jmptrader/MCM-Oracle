#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: sybase.pl [ -kill <|all> ]

 -kill <all>          Kill all sessions       
 -help                Display this text.

EOT
;
    exit;
}

#
# process the commandline arguments
#
my ($kill);

GetOptions(
    'kill=s'       => \$kill,
    'help'         => \&usage,
);

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sybase' );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_SAUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection (without specifying the database name)
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

#
# determine the name of the dabase
#
my $db_name = $config->DB_NAME;

$logger->info('killing al the Sybase connections');

if ( $sybase->kill_all( $db_name ) ) {
    $logger->info('all Sybase connections are killed');
    print "all Sybase connections are killed\n";
}
else {
    $logger->warn('unable to kill all Sybase connections');
    print "unable to kill all Sybase connections\n";
}

$sybase->close();
