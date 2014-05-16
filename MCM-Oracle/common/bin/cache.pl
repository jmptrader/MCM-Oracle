#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Process;
use Getopt::Long;
use File::Basename;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: cache.pl [ -i <inputfile> ] [ -o <outputfile> ] [ -u <cacheuser> ] [ -help ]

 -i <inputfile>       Name of the file to load into the cache
 -o <outputfile>      Name of the results file 
 -u <cacheuser>       Name of the cache page
 -help                Display this text.

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
my ($inputfile, $outputfile, $cacheuser);

GetOptions(
    'i=s'     => \$inputfile,
    'o=s'     => \$outputfile,
    'u=s'     => \$cacheuser,
    'help'    => \&usage,
);

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'cache' );

#
# initialize auditing
#
my $audit   = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'cache', logger => $logger );

$audit->start($args);

#
# check the commandline
#
unless ( $inputfile ) {
    $audit->end("no inputfile specified", 1);
}
unless ( -f $inputfile ) {
    $audit->end("inputfile ($inputfile) cannot be read", 1);
}
unless ( $cacheuser ) {
    $audit->end("no cacheuser specified", 1);
}

#
# determine the workdirectory from where the command must be launched
#
my $directory = $config->MXENV_ROOT;

#
# insert an identifier in the command to identify the process
#
my $identifier = ' /scripttype:cacheload /scriptname:' . basename($inputfile) . ' /dbname:' . $config->DB_NAME;

#
# Prepare the command line for an optional argument : output_file
#
my $output_option = "";
if( defined( $outputfile ) )
{  $output_option = ' -o ' . $outputfile;
}

#
# build the command
#
my $command = $config->JAVA_HOME.'/bin/java -Xmx1g -cp .:./mxjboot.jar'.
   ' -Dmurex.application.codebase=http://'.$config->MXJ_FILESERVER_HOST.':'.
   $config->MXJ_FILESERVER_PORT . '/integration.cachetool.download.cachetool.download'.
   ' murex.rmi.loader.RmiLoader' .
   ' /MXJ_CLASS_NAME:murex.realtime.tools.cachetool.CacheQueryServiceCommandLine\$CacheQueryServiceCommandLineRunnable' .
   ' /MXJ_SITE_NAME:'.$config->MXJ_SITE_NAME.
   $identifier.
   ' -i '.$inputfile.$output_option.
   ' -u '.$cacheuser
;

#
# run the command
#
my ($success, $exitcode, $output) = Mx::Process->run( 
    command => $command, directory => $directory, no_output => 1, config => $config, logger => $logger
);

#
# convert errorcodes > 256
#
$exitcode = $exitcode % 256;

$audit->end($args, $exitcode);

