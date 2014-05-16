#!/usr/bin/env perl

# ---------------------------------------------------------------------------- #
# copy_report                                                                  #
# ---------------------------------------------------------------------------- #
#                                                                              #
# Date      User    Change                                                     #
# --------  ------  ---------------------------------------------------------- #
# 20100406  U77943  MX V3 Project                                              #
#                                                                              #
# ---------------------------------------------------------------------------- #
#                                                                              #
# Info                                                                         #
# ----                                                                         #
# -inpath     can be a file or folder (default folder = data/ENV/reports2)     #
# -outpath    can only be a folder    (filenames are kept from input file(s)   #
# -project    project folder name     (e.g.: mo_report_ibs / bo_conf           #
#                                                                              #
# shortcuts are defined for folders                                            #
# ---------------------------------                                            #
# /d          data dir     project folder                                      #
# /t          transfer dir project folder                                      #
# /e          enduser  dir project folder                                      #
# /r          rootdir murex installation                                       #
#                                                                              #
# examples                                                                     #
# --------                                                                     #
# copy_report.pl -inpath /vrm/vrm001.csv -outpath /d -project mo_report_vrm    #
# => copy data/ENV/reports2/vrm/vrm001.csv to mo_report_vrm/data/vrm001.txt    #
#                                                                              #
# copy_report.pl -inpath r/irocad.txt -outpath /e/iro/ mo_report_vrm           #
# => copy /murex/murex1/ENV/irocad.txt to mo_report_vrm/enduser/iro/irocad.txt #
#                                                                              #
# copy_report.pl -inpath /vcr/ -outpath /t/ mo_report_vcr                      #
# => copy data/ENV/reports2/vcr/* to mo_report_vcr/transfer/DATE/*             #
#                                                                              #
# ---------------------------------------------------------------------------- #

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Util;
use Getopt::Long;
use File::Copy;
use File::Basename;

    
#---------#
sub usage {
#---------#
    print <<EOT

Usage: copy_report.pl -inpath <inpath> -outpath <outpath> -project <project> 
 -inpath     <inpath>       input path (single file or folder)
 -outpath    <outpath>      output path
 -project    <project>      project folder
 -help                      display this text

EOT
;
    exit;
};


# 
# store away the commandline arguments for later reference
#
my $args = "@ARGV";


#
# get the script arguments
#
my ( $parm_inpath, $parm_outpath, $parm_project );

GetOptions(
    'help'        => \&usage,
    'inpath=s'    => \$parm_inpath,
    'outpath=s'   => \$parm_outpath,
    'project=s'   => \$parm_project    
);

unless ( $parm_inpath && $parm_project ) {
    usage();
};


#
# read the configuration files
#
my $config = Mx::Config->new();
$config->set_project_variables( $parm_project );


#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->KBC_LOGDIR, keyword => 'copy_report' );
$logger->info("copy_report.pl $args");


#--------------------------------------------------------------------------------------------
# Main Processing
#--------------------------------------------------------------------------------------------

my $DATADIR     = $config->KBC_DATADIR;
my $ENDUSERDIR  = $config->KBC_ENDUSERDIR;
my $TRANSFERDIR = $config->KBC_TRANSFERDIR;
my $ROOTDIR     = $config->MXENV_ROOT;

my $REPORTDIR   = $config->REPORT_OUTPUT_DIR_2;

my ( $path_from, $path_to );

my %subst = ( 'd/' => $DATADIR,
              'e/' => $ENDUSERDIR,
              't/' => $TRANSFERDIR,
              'r/' => $ROOTDIR     );


# check if from path exists
#~~~~~~~~~~~~~~~~~~~~~~~~~~
$parm_inpath = substr( $parm_inpath, 1) if ( substr( $parm_inpath, 0, 1 ) eq '/' );

my $dir = substr( $parm_inpath, 0, 2);

if ( $subst{ $dir } ) {
    $parm_inpath = $subst{ $dir } . '/' . substr( $parm_inpath, 2 );
}
else {
    $parm_inpath = $REPORTDIR . '/' . $parm_inpath;
}

$path_from = $parm_inpath;

$logger->info( 'Input  [' . $path_from . ']' );

if ( ! -e $path_from ) {
    $logger->logdie( 'Report not found [' . $path_from . ']' );
}      


# check outputdir
#~~~~~~~~~~~~~~~~
if ( $parm_outpath ) {

    $parm_outpath  =  substr( $parm_outpath, 1 ) if ( substr( $parm_outpath, 0, 1 ) eq '/' );
    $parm_outpath .= '/' if ( substr( $parm_outpath, -1, 1 ) ne '/' );
               
    my $projectdir = substr( $parm_outpath, 0, 2 );
	
    if ( $subst{ $projectdir } ) {
	      $parm_outpath = $subst{ $projectdir } . '/' . substr( $parm_outpath, 2 );
    }
    else {
        $parm_outpath = $TRANSFERDIR.'/'.$parm_outpath;
    }
}
else {
    $parm_outpath = $TRANSFERDIR.'/';
}


$path_to = $parm_outpath;

$logger->info('Output [' . $path_to . ']' );


# check if output folder exists
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
my ( $filename, $directories ) = fileparse( $path_to );

if ( $directories ne './' ) {
   
    unless( Mx::Util->mkdir( logger => $logger, directory => $path_to ) ){
        $logger->info( 'Unable to create [' . $path_to . ']' );
    };
}


# copy single file or directory
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if ( substr ( $parm_inpath, -1 ,1 ) eq '/' ) {
    
    my $fh_data;

    opendir( $fh_data, $path_from ) || die "Error in opening dir $path_from \n";

    while( my $file = readdir( $fh_data ) ) {
        next if $file =~/^\./;

        my $from = $path_from . '/' . $file;
        my $to   = $path_to   . '/' . $file;

        # copy file to end user location
        copy ( $from, $to ) or die "$path_from cannot be copied";
    }
    
}
else {
    
    $path_to .= $filename;    
    
    copy ( $path_from, $path_to ) or die "$path_from cannot be copied";    
    
}

exit(0);
