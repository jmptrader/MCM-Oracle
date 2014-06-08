#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Template;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: create_config.pl [ -check ] [ -apply ] [ -confirm ] [ -nobackup ]

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

my $config     = Mx::Config->new();
my $logger     = Mx::Log->new( directory => $config->LOGDIR, keyword => 'create_config' );
my $edw_config = $config->derive( 'EDW_CONFIGFILE' );

my $template_file = $config->LOCAL_DIR . '/' . $config->MXUSER . '/code/MurexEnv_any.xml';
my $target_file   = $config->LOCAL_DIR . '/' . $config->MXUSER . '/code/config/MurexEnv_' . $ENV{MXENV} . '.xml';

my $template = Mx::Template->new( path => $template_file, tag_type => $Mx::Template::AT_TAG, logger => $logger );

$template->process( params => $edw_config );

my $output;
exit 0 if $template->compare( target => $target_file, output => \$output );

print "$output\n";

if ( $do_apply ) {
    exit $template->install( no_backup => $no_backup ) ? 0 : 1;
}

if ( $do_confirm ) {
    my $answer;
    while ( ! $answer ) {
        print "\nReplace $target_file? [y/N] ";
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
        exit $template->install( no_backup => $no_backup ) ? 0 : 1;
    }
}
