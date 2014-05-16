#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::EDW;
use Mx::Account; 
use Mx::Template;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: create_config.pl [ -check ] [ -apply ] [ -nobackup ]

 -check       Only report the differences, do not make changes.
 -apply       Replace the files which are different.
 -nobackup    Do not keep a copy of the replaced files.
 -help        Display this text.

EOT
;
    exit;
}

my ($do_check, $do_apply, $no_backup);

GetOptions(
    'check'      => \$do_check,
    'apply'      => \$do_apply,
    'nobackup'   => \$no_backup
);

unless ( $do_check or $do_apply ) {
    usage();
}

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'create_config' );

my $template_path = $config->XMLDIR . '/MurexEnv_any.xml';
my $target_path   = $config->LOCAL_DIR . '/' . $config->MXUSER . '/code/config/MurexEnv_' . $config->MXENV . '.xml';

my $fin_account = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
my $rep_account = Mx::Account->new( name => $config->REP_DBUSER, config => $config, logger => $logger );

my $edw = Mx::EDW->new( config => $config, logger => $logger );

$edw->add_to_config(
   ORACLE_FIN_ENC_PASSWORD => $fin_account->murex_password,
   ORACLE_DM_ENC_PASSWORD  => $rep_account->murex_password
);

my $template = Mx::Template->new( path => $template_path, tag_type => $Mx::Template::AT_TAG, logger => $logger );

$template->process( params => $edw );

my $output;
$template->compare( target => $target_path, output => \$output );

print "$output\n";

my $rc = 0;
if ( $do_apply ) {
    $template->install( no_backup => $no_backup ) || ( $rc = 1 );
}

exit $rc;
