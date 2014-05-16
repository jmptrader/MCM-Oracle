#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Account;
use Mx::Sybase;
use Mx::Macro;
use Getopt::Long;
use POSIX;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: poc_macro.pl [ -name <macro_name> ] [ -runid <id> ] [ -debug ] [ -help ]

 -name <macro_name>      Name of the macro to execute.
 -runid <id>             ID of the values to use for the placeholders.
 -debug                  Generate a Murex trace file.
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
my ($name, $run_id, $debug);

GetOptions(
  'name=s'  => \$name,
  'runid=i' => \$run_id,
  'debug!'  => \$debug,
  'help'    => \&usage
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'poc_macro' );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'poc_macro', logger => $logger );

$audit->start($args);

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_SAUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->MONDB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

#
# lookup the macro in the database
#
my $result = $sybase->query( query => 'select id, path from macros where name = ?', values => [ $name ] );

my $nr_results = @{$result};
if ( $nr_results == 0 ) {
    $audit->end("no macro found with name $name", 1);
}
elsif ( $nr_results > 1 ) {
    $audit->end("more than one macro found with name $name", 1);
}

my ($macro_id, $path) = @{$result->[0]};

#
# build the file containing values for all placeholders
#
my $cfgfile;
if ( $run_id ) {
    #
    # check if a valid runid was specified
    #
    $result = $sybase->query( query => 'select id from macro_runs where macro_id = ?', values => [ $macro_id ] );
    my @run_ids = map { $_->[0] } @{$result};

    unless ( grep /^$run_id$/, @run_ids ) {
        $audit->end("runid $run_id is not a valid id for macro $name", 1);
    }
    #
    # retrieve the values from the database
    #
    $result = $sybase->query( query => 'select placeholder, value from macro_values where macro_run_id = ?', values => [ $run_id ] );

    $cfgfile = $config->retrieve('RUNDIR') . "/macro_run_values_$run_id.cfg.$$";
    my $cfg;
    unless ( $cfg = IO::File->new( $cfgfile, '>' ) ) {
        $audit->end("cannot create $cfgfile: $!", 1);
    }
    #
    # store the values in a temporary file
    #
    foreach my $entry ( @{$result} ) {
        my ( $placeholder, $value ) = @{$entry};
        print $cfg "$placeholder = $value\n";
    }
    my $nick = ( $debug ) ? 'MXDEBUG' : 'MX'; 
    print $cfg "__NICKNAME__ = $nick\n";
    $cfg->close();
}

#
# initialize the script
#
my $script;
unless ( $script = Mx::Macro->new( name => $name, template => $path, cfgfile => $cfgfile, config => $config, logger => $logger ) ) {
    $audit->end( $Mx::Macro::errstr, 1 );
}

$script->run( exclusive => 1 );

unlink($cfgfile);

$sybase->close();

$audit->end($args, $script->exitcode);
