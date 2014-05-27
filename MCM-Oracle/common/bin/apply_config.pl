#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::XMLConfig;
use Mx::Template;
use File::Find;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: apply_config.pl [ -check ] [ -apply ] [ -confirm ] [ -nobackup ]

 -check       Only report the differences, do not make changes.
 -apply       Replace the files which are different.
 -confirm     Manually confirm each replacement.
 -nobackup    Do not keep a copy of the replaced files.
 -help        Display this text.

EOT
;
    exit;
}

my ($do_check, $do_apply, $do_confirm, $no_backup);

GetOptions(
    'check'      => \$do_check,
    'apply'      => \$do_apply,
    'confirm'    => \$do_confirm,
    'nobackup'   => \$no_backup
);

unless ( $do_check or $do_apply or $do_confirm ) {
    usage();
}

my $config    = Mx::Config->new();
my $logger    = Mx::Log->new( directory => $config->LOGDIR, keyword => 'apply_config' );
my $xmlconfig = Mx::XMLConfig->new();

my $template_dir = $config->LOCAL_DIR . '/' . $config->MXUSER . '/code/apptree';
my $target_dir   = $config->MXENV_ROOT; 

my $rc = 0;

find( \&wanted, $template_dir );

sub wanted {
    my $path = $File::Find::name;

    return unless -f $path; 

    my $template = Mx::Template->new( path => $path, logger => $logger );

    $template->process( params => $xmlconfig );

    my $target = $path;
    $target =~ s/^$template_dir/$target_dir/;

    my $output;
    return if $template->compare( target => $target, output => \$output );

    print "$output\n";

    if ( $do_apply ) {
        $template->install( no_backup => $no_backup ) || ( $rc = 1 );
    }
    elsif ( $do_confirm ) {
        my $answer;
        while ( ! $answer ) {
            print "\nReplace $target? [y/N] ";
            $answer = <STDIN>;
            chomp($answer);

            if ( $answer =~ /^y[es]?$/i ) {
                $answer = 'yes';
                print "\n\n";
            }
            elsif ( ! $answer or $answer =~ /^n[o]?$/i ) {
                $answer = 'no';
                print "\n\n";
            }
            else {
                $answer = '';
            }
        }

        if ( $answer eq 'yes' ) {
            $template->install( no_backup => $no_backup ) || ( $rc = 1 );
        }
    }
}

exit $rc;
