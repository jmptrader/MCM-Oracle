#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase2;
use Mx::Process;
use Getopt::Long;
use IO::File;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: sql_statement.pl [ -name <statementname> ] [ -project <projectname> ] [ -sched_js <stream> ] [ -ifile <inputfile> ] [ -help ]

 -name <statementname>       Name of the statement to execute.
 -project <projectname>      Name of the project to which the statement belongs.
 -sched_js <stream>          Jobstream name in the scheduler.
 -ifile <inputfile>          Inputfile that contains the statement.
 -help                       Display this text.

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
my ($name, $project, $sched_js, $inputfile);

GetOptions(
    'name=s'        => \$name,
    'project=s'     => \$project,
    'sched_js=s'    => \$sched_js,
    'ifile=s'       => \$inputfile,
    'help!'         => \&usage,
);

unless ( $name and $project and $sched_js and $inputfile ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

$config->set_project_variables( $project );

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->PROJECT_LOGDIR, keyword => $sched_js );

$logger->info("sql_statement.pl $args");

my $statement = '';
my $fh;
unless ( $fh = IO::File->new( "$inputfile", '<' ) ) {
    $logger->logdie("cannot open inputfile ($inputfile): $!");
}

while ( <$fh> ) {
    $statement .= $_;
}

$fh->close();

chomp($statement);

$logger->info("starting execution of statement $name");
$logger->info("[$statement]");

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

#
# open the Sybase connection
#
$sybase->open();

#
# make sure you run exclusively
#
my $process = Mx::Process->new( descriptor => $name, logger => $logger, config => $config );
unless ( $process->set_pidfile($0) ) {
    $logger->logdie("not running exclusively");
}

my $duration = time();

my $nr_rows = $sybase->do( statement => $statement );

$duration = time() - $duration;

$sybase->close();

$process->remove_pidfile();

if ( $nr_rows eq '0E0' or $nr_rows > 0 ) {
    $logger->info("statement $name succeeded (number of rows: $nr_rows  duration: $duration seconds)");
    exit 0;
}

$logger->logdie("statement $name failed");
