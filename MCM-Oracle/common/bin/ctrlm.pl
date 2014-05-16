#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::ControlM::Table;
use Mx::ControlM::Job;
use Mx::EDW;
use Mx::DBaudit;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: ctrlm.pl [ -update ] [ -edw ] [ -help ]

 -update      Reparse the GIT repository.
 -edw         Replace the EDW placeholders.
 -help        Display this text.

EOT
;
    exit;
}

my ($do_update, $do_edw);

GetOptions(
    'update'  => \$do_update,
    'edw'     => \$do_edw
);

unless ( $do_update ) {
    usage();
}

my $config = Mx::Config->new();

my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'ctrlm' );

my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $gitrepo = $config->LOCAL_DIR . '/' . $config->MXUSER . '/mx_release/ctrlm_drop6/forexclear-ctrlm/ForexClear-CTRLM/tables';

unless ( -d $gitrepo ) {
    $logger->logdie("ControlM GIT repo not found ($gitrepo)");
}

my $edw = ( $do_edw ) ? Mx::EDW->new( logger => $logger, config => $config ) : undef;

$db_audit->cleanup_ctrlm;

Mx::Util->rmdir( directory => $config->CTRLMDIR, logger => $logger );

chdir($gitrepo);

opendir DIR, $gitrepo;

while ( my $file = readdir(DIR) ) {
    next unless $file =~ /\.xml$/;

    my $table = Mx::ControlM::Table->new( file => $file, edw => $edw, config => $config, logger => $logger );

    $table->store( db_audit => $db_audit );
    $table->dump_xml();

    foreach my $job ( $table->jobs ) {
		$job->store( db_audit => $db_audit );
		$job->dump_xml();

		print $job->name . "\n";
    }
}

closedir(DIR);
