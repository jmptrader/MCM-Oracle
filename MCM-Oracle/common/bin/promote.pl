#!/usr/bin/env perl
 
use warnings;
use strict;
 
use Getopt::Long;
use File::Copy;
 
#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: promote.pl [ -source <sourcedirectory> ] [ -target <targetdirectory> ] [ -help ]

 -source <sourcedirectory>     Directory containing all the latest versions.
 -target <targetdirectory>     Directory containing all the files to be replaced.
 -help                         Display this text.
 
EOT
;
    exit;
}
 
#
# process the commandline arguments
#
my ($sourcedir, $targetdir);
 
GetOptions(
    'source=s'      => \$sourcedir,
    'target=s'      => \$targetdir,
    'help'          => \&usage,
);

unless ( $sourcedir && $targetdir ) {
    usage();
}

unless ( -d $sourcedir ) {
    print "source directory does not exist\n";
    exit 1;
}

unless ( -d $targetdir ) {
    print "target directory does not exist\n";
    exit 1;
}

unless ( opendir SOURCE, $sourcedir ) {
    print "cannot access source directory: $!\n";
    exit 1;
}

while ( my $file = readdir(SOURCE) ) {
    next if $file eq '.' or $file eq '..';

    my $sourcefile = $sourcedir . '/' . $file;
    my $targetfile = $targetdir . '/' . $file;

    next unless -f $sourcefile;

    printf "checking %s", $file . '.' x (30 - length($file));

    if ( ! -f $targetfile ) {
        print "not present.\n";
        print "Should I copy this file? (Y/N) ";
        my $answer = <STDIN>;
        chomp($answer);
        if ( $answer eq 'y' or $answer eq 'Y' ) {
            if ( copy $sourcefile, $targetfile ) {
                print "copy succeeded\n";
                system("chmod -w $targetfile");
            }
            else {
                print "copy failed: $!\n";
                exit 1;
            }
        }
    }
    else {
        my $source_checksum = checksum( $sourcefile );
        my $target_checksum = checksum( $targetfile );

        if ( $source_checksum == $target_checksum ) {
            print "OK\n"
        }
        else {
            print "Should I list differences? (Y/N) ";

            my $answer = <STDIN>;
            chomp($answer);

            if ( $answer eq 'y' or $answer eq 'Y' ) {
                system("diff $sourcefile $targetfile");
            }

            print "Should I replace the file? (Y/N) ";

            $answer = <STDIN>;
            chomp($answer);

            if ( $answer eq 'y' or $answer eq 'Y' ) {
                system("chmod +w $targetfile");

                if ( copy $sourcefile, $targetfile ) {
                    print "copy succeeded\n";
                }
                else {
                    print "copy failed: $!\n";
                    exit 1;
                }

                system("chmod -w $targetfile");
            }
        }
    }
}

closedir(SOURCE);


#------------#
sub checksum {
#------------#
    my ( $file ) = @_;

    
    open CMD, "/usr/bin/cksum $file|";
    my $output = <CMD>;
    close(CMD);

    my ($checksum) = $output =~ /^(\d+)\s+\d+\s+\S+$/;

    return $checksum;
}
