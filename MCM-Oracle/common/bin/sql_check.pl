#!/usr/bin/env perl

use warnings;
use strict;

use constant MAX_UNCOMPRESSED_SIZE => 1024;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Murex;
use Mx::Script;
use Mx::Util;
use Getopt::Long;
use File::Basename;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: sql_extract.pl [ -name <library_tag> ] [ -output <csv file> ] [ -separator <separator> ] [ -quoted ] [ -yesterday ] [ -mail <addresses> ] [ -help ]

 -name <library_tag>     identifier of the SQL portion in the SQL library
 -output <csv file>      csv file which will contain the result of the SQL query
 -separator <separator>  separator in the csv file (optional, default is comma)
 -quoted                 boolean indicating if all fields must be quoted
 -yesterday              boolean indicating that the date placeholder in the SQL must be set to FO date - 1
 -mail <addresses>       Adresses to which the csv file must be sent.
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
my ($name, $file, $separator, $quoted, $yesterday, $mail);

GetOptions(
    'name=s'        => \$name,
    'file=s'        => \$file,
    'separator=s'   => \$separator,
    'quoted!'       => \$quoted,
    'yesterday!'    => \$yesterday,
    'mail=s'        => \$mail,
    'help!'         => \&usage,
);

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new(
  directory => $config->LOGDIR,
  keyword   => 'sql_extract',
);

#
# initialize auditing
#
my $audit   = Mx::Audit->new(
  directory => $config->AUDITDIR,
  keyword   => 'sql_extract',
  logger    => $logger,
);

$audit->start($args);

#
# setup the Sybase account
#
my $account = Mx::Account->new(
  name     => $config->SQLUSER,
  config   => $config,
  logger   => $logger,
); 

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase->new(
  dsquery       => $config->DSQUERY,
  database      => $config->DB_NAME,
  username      => $account->name,
  password      => $account->password,
  error_handler => 1,
  config        => $config,
  logger        => $logger,
);

#
# open the Sybase connection
#
$sybase->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new(
  file   => $config->SQLLIBRARY,
  logger => $logger,
);

#
# retrieve the query from the library
#
my $query;
unless ( $query = $sql_library->query($name) ) {
    $audit->end("cannot retrieve sql with tag '$name' from the library", 1);
}

#
# make sure you run exclusively
#
my $process = Mx::Process->new( descriptor => $name, logger => $logger, config => $config );
unless ( $process->set_pidfile($0) ) {
    $audit->end("not running exclusively", 1);
}

#
# retrieve the Murex FO date
#
my $fo_date = Mx::Murex->date(type => 'FO',  appl_type => 'EQD', sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
my $prev_fo_date;
if ( $yesterday ) {
    $prev_fo_date   = Mx::Murex->date(type => 'FO',  shift => -1, appl_type => 'EQD', sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
}

#
# replace the placeholders in the query
#
$query =~ s/__FODATE__/$fo_date/sg;
if ( $yesterday ) {
    $query =~ s/__DATE__/$prev_fo_date/sg;
}
else {
    $query =~ s/__DATE__/$fo_date/sg;
}

#
# execute the query
#
my ($result, $names);
unless ( ($result, $names) = $sybase->query( query => $query ) ) {
    $audit->end('sql query failed', 1);
}

$sybase->close();
$process->remove_pidfile();

$audit->end($args, @{@{$result}[0]}[0]);

