#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Secondary;
use Mx::FileSync;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: filesync.pl [ -s <source directory> ] [ -t <target directory> ] [ -i <instance> ] [ -r ] [ -h ]

 -s <source directory>      Directory on the local host to be synced.
 -t <target directory>      Directory on the target host to be synced. Set to source directory if not specified.
 -i <instance>              Instance number of the target server.
 -r                         Sync the directory recursively.
 -n                         Do not sync, only show differences.
 -h                         Display this text.

EOT
;
    exit;
}

#
# process the commandline arguments
#
my ($sourcedir, $targetdir, $instance, $recursive, $do_not_sync);

GetOptions(
    's=s'    => \$sourcedir,
    't=s'    => \$targetdir,
    'i=s'    => \$instance,
    'r!'     => \$recursive,
    'n!'     => \$do_not_sync, 
    'h!'     => \&usage,
);

unless ( $sourcedir && defined( $instance ) ) {
    usage();
}

unless ( $instance =~ /^\d+$/ ) {
    print "invalid instance number\n";
}

$recursive ||= 0;
$targetdir ||= $sourcedir;

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'filesync' );

#
# connect to the secondary monitor (if there is one)
#
my $handle;
unless ( $handle = Mx::Secondary->handle( instance => $instance, config => $config, logger => $logger ) ) {
    $logger->logdie("cannot connect to instance $instance");
}

Mx::Secondary->init( logger => $logger, config => $config );

my $local_filesync = Mx::FileSync->new( target => $sourcedir, recursive => $recursive, logger => $logger );

$local_filesync->analyze();

my $remote_filesync = $handle->soaphandle->filesync( target => $targetdir, recursive => $recursive )->paramsall;

foreach my $difference ( $local_filesync->compare( $remote_filesync ) ) {
    Mx::FileSync->print_difference( $difference );

    my $source_path = ( $difference->[1] ) ? ( $sourcedir . '/' . $difference->[0] ) : undef;
    my $target_path = ( $difference->[2] ) ? ( $targetdir . '/' . $difference->[0] ) : undef;

    while ( ! $do_not_sync ) {
        print "\nIgnore (I), update source (S), update target (T) [default: I]: ";

        my $answer = <STDIN>;

        chomp( $answer );

        my $rc = 0;
        if ( $answer eq 'I' or $answer eq '' ) {
            last;
        }
        elsif ( $answer eq 'S' ) {
            if ( $target_path ) {
                if ( $source_path ) {
                    print "\noverwriting $source_path on source\n";
                }
                else {
                    $source_path = $sourcedir . '/' . $difference->[0];
                    print "\ncreating $source_path on source\n";
                }

                if ( my $content = $handle->soaphandle->read_file( path => $target_path )->paramsall ) {
                    $rc = Mx::Secondary->write_file( path => $source_path, content => $content, perms => $difference->[2][2] );
                }
            }
            else {
                print "\ndeleting $source_path on source\n";
                $rc = Mx::Secondary->delete_file( path => $source_path );
            }

            my $message = ( $rc ) ? 'Success' : 'Failed';

            print "$message\n";

            last;
        }
        elsif ( $answer eq 'T' ) {
            if ( $source_path ) {
                if ( $target_path ) {
                    print "\noverwriting $target_path on target\n";
                }
                else {
                    $target_path = $targetdir . '/' . $difference->[0];
                    print "\ncreating $target_path on target\n";
                }

                if ( my $content = Mx::Secondary->read_file( path => $source_path ) ) {
                    $rc = $handle->soaphandle->write_file( path => $target_path, content => $content, perms => $difference->[1][2] );
                }
            }
            else {
                print "\ndeleting $target_path on target\n";
                $rc = $handle->soaphandle->delete_file( path => $target_path );
            }

            my $message = ( $rc ) ? 'Success' : 'Failed';

            print "$message\n";

            last;
        }
    }
}

print "\n";
