#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Project;
use Mx::Murex;
use Mx::Util;
use Mx::FileCleanup;
use Getopt::Long;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: cleanup.pl [ -sessions ] [ -projects ] [ -archive ] [ -files ] [ -help ]

 -sessions         Cleanup everything related to Murex sessions.  
 -projects         Archive everything related to projects.
 -archive          Cleanup the projects archive.
 -files            Cleanup files based on the cleanup_files.cfg
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
my ($sessions, $projects, $archive, $files);
 
GetOptions(
    'sessions!'  => \$sessions,
    'projects!'  => \$projects,
    'archive!'   => \$archive,
    'files!'     => \$files,
    'help'       => \&usage,
);

unless ( $sessions or $projects or $archive or $files ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'cleanup' );

$logger->info("cleanup.pl $args");
my $hostname = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;


###################
#                 #
# session cleanup #
#                 #
###################

if ( $sessions ) {
    $logger->info("starting session cleanup");

    my $retention_days = $config->retrieve('HIST_RETENTION_DAYS');
    $logger->info("retention period: $retention_days days");

    my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

    $db_audit->report();

    my @ids = $db_audit->cleanup_sessions( retention => $retention_days );

    $db_audit->cleanup_logfiles( retention => $retention_days );
    $db_audit->cleanup_scripts( retention => $retention_days );
    $db_audit->cleanup_runtimes( retention => $retention_days );
    $db_audit->cleanup_jobs( retention => $retention_days );
    $db_audit->cleanup_mxml_nodes_hist( retention => $retention_days );

    my @statement_ids = $db_audit->cleanup_statements( retention => $retention_days );

    my $coredir     = $config->COREDIR;
    my $sqltracedir = $config->SQLTRACEDIR;
    my $showplandir = $config->SHOWPLANDIR;
    my $stdoutdir   = $config->MXENV_ROOT . '/logs/sessions';
    my $mmsdir      = $config->MMSDIR;

    my $nr_cores     = 0;
    my $nr_sqltraces = 0;
    my $nr_showplans = 0;
    my $nr_stdouts   = 0;
    my $nr_mms       = 0;

    foreach my $id ( @ids ) {
        $nr_cores     += unlink "${coredir}/${id}.pstack";
        $nr_sqltraces += unlink "${sqltracedir}/${id}.trc";
        $nr_stdouts   += unlink "${stdoutdir}/${id}.stdout";
        $nr_mms       += unlink "${mmsdir}/${id}.txt";
    }

    $logger->info("$nr_cores cores cleaned up");
    $logger->info("$nr_sqltraces SQL traces cleaned up");
    $logger->info("$nr_stdouts STDOUT logs cleaned up");
    $logger->info("$nr_mms MMS logs cleaned up");

    foreach my $id ( @statement_ids ) {
        $nr_showplans += unlink "${showplandir}/${id}.sp";
    }

    $logger->info("$nr_showplans showplans cleaned up");

    $db_audit->report();

    $db_audit->close();

    $logger->info("session cleanup finished");
}

#####################
#                   #
# project archiving #
#                   #
#####################

if ( $projects ) {
    $logger->info("starting project archive");

    my @projects = Mx::Project->retrieve_all( config => $config, logger => $logger );

    my $total_size = 0; my $total_starttime = time();

    foreach my $project ( @projects ) {
        my $name = $project->name;

        $logger->info("archiving project $name");

        $config->set_project_variables( $name );

        my $project_size = 0; my $project_starttime = time();

        foreach my $key ( 'log', 'transfer' ) {
            my $dir; my $retention_days;
            if ( $key eq 'log' ) {
                $dir            = $config->KBC_LOGDIR;
                $retention_days = $project->log_retention_days;
            }
            elsif ( $key eq 'transfer' ) {
                $dir            = $config->KBC_TRANSFERDIR;
                $dir            =~ s/\/\d+$//; 
                $retention_days = $project->transfer_retention_days;
            }

            my $archdir = $config->KBC_ARCHDIR . '/' . $key;

            my $retention_date = Mx::Murex->calendardate( time() - $retention_days * 86400 );

            unless ( -d $archdir ) {
                Mx::Util->mkdir( directory => $archdir, logger => $logger );
            }

            $logger->info("archiving all $key directories older than $retention_date");

            unless ( opendir DIR, $dir ) {
                $logger->error("cannot open $dir: $!");
                next;
            }

            while ( my $date = readdir( DIR ) ) {
                if ( $date =~ /^\d{8}$/ and $date < $retention_date  ) {
                    my $full_dir = "$dir/$date";
                    my $dirsize = Mx::Util->dirsize( directory => $full_dir, logger => $logger );

                    $project_size += $dirsize;

                    my $dirsize_conv = Mx::Util->convert_bytes( $dirsize );

                    $logger->info("$full_dir has a size of $dirsize_conv");

                    unless ( Mx::Util->tar( tarfile => "$archdir/$date.tar", workdir => $dir, files => [ $date ], logger => $logger, config => $config ) ) {
                        $logger->logdie("cannot tar");
                    }

                    unless ( Mx::Util->compress( sourcefile => "$archdir/$date.tar", targetfile => "$archdir/$date.tar.gz", erase => 1, logger => $logger, config => $config ) ) {
                        $logger->logdie("cannot compress");
                    }

                    unless ( Mx::Util->rmdir( directory => "$dir/$date", remove => 1, logger => $logger ) ) {
                        $logger->logdie("cannot remove");
                    }
                }
            }

            closedir( DIR );
        }

        $total_size += $project_size;

        my $project_size_conv = Mx::Util->convert_bytes( $project_size );
        my $project_duration = time() - $project_starttime; 

        $logger->info("project $name: $project_size_conv archived in $project_duration seconds");
    }

    my $total_size_conv = Mx::Util->convert_bytes( $total_size );
    my $total_duration = time() - $total_starttime;

    $logger->info("$total_size_conv archived in $total_duration seconds");

    $logger->info("project archive finished");
}

###################
#                 #
# archive cleanup #
#                 #
###################

if ( $archive ) {
    $logger->info("starting archive cleanup");

    my @projects = Mx::Project->retrieve_all( config => $config, logger => $logger );

    foreach my $project ( @projects ) {
        my $name = $project->name;

        $logger->info("cleaning up project $name");

        $config->set_project_variables( $name );

        foreach my $key ( 'log', 'transfer' ) {
            my $archdir  = $config->KBC_ARCHDIR . '/' . $key;

            my $retention_days;
            if ( $key eq 'log' ) {
                $retention_days = $project->arch_log_retention_days;
            }
            elsif ( $key eq 'transfer' ) {
                $retention_days = $project->arch_transfer_retention_days;
            }

            my $retention_date = Mx::Murex->calendardate( time() - $retention_days * 86400 );

            unless ( opendir DIR, $archdir ) {
                $logger->error("cannot open $archdir: $!");
                next;
            }
      
            while ( my $file = readdir( DIR ) ) {
                if ( $file =~ /^(\d{8})\.tar\.gz$/ ) {
                    my $date = $1;
                    if ( $date < $retention_date ) {
                        $logger->info("removing $file in $archdir");
                        unlink( "$archdir/$file" );
                    }
                }
            }

            closedir( DIR );
        }

    }

    $logger->info("archive cleanup finished");
}



###################
#                 #
# files cleanup   #
#                 #
###################

if ( $files ) {
    $logger->info("starting files cleanup");

    my @cleanups = Mx::FileCleanup->retrieve_all( config => $config, logger => $logger );

    foreach my $cleanup ( @cleanups ) {
      $cleanup->delete() ;
    }

}
