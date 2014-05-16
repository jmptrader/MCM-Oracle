#!/usr/bin/env perl

use Mx::Log;
use Mx::Config;
use Mx::DBaudit;
use Mx::ResourcePool;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: resources.pl [ -setup ] [ -reset ] [ -globalreset ]

 -setup        Setup a new resourcepool from scratch.
 -reset        Reset the resourcepool for this server only.
 -globalreset  Reset the entire resourcepool.
 -help         Display this text.

EOT
;
    exit;
}

# Store the arguments
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($setup, $reset, $globalreset);

GetOptions(
    'setup!'        => \$setup,
    'reset!'        => \$reset,
    'globalreset!'  => \$globalreset,
    'help'          => \&usage,
);

unless ( $setup or $reset or $globalreset ) {
    usage();
}

if ( $reset && Mx::Process->ostype eq 'linux' ) {
    print "local reset not allowed on RHEL\n";
    exit 1;
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'resources' );

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

my $resourcepool = Mx::ResourcePool->new( config => $config, logger => $logger, db_audit => $db_audit );

if ( $setup ) {
    $resourcepool->setup();
}

if ( $reset ) {
    $resourcepool->reset();
}

if ( $globalreset ) {
    $resourcepool->globalreset();
}
