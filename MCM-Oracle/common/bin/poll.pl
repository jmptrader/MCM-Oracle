#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Secondary;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: poll.pl [ -i <instance> ] [ -k <key> ] [ -help ]

 -i <instance>        Instance number of the application server.
 -k <key>             Key returned by remote background command.
 -help                Display this text.

EOT
;
    exit 1;
}

#
# process the commandline arguments
#
my ($instance, $key);

GetOptions(
    'i=s'        => \$instance,
    'k=s'        => \$key,
    'help'       => \&usage,
);

unless ( defined( $instance ) && $key ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'remote' );

#
# connect to the secondary monitor (if there is one)
#
if ( my $handle = Mx::Secondary->handle( instance => $instance, config => $config, logger => $logger ) ) {
    my ( $success, $error_code, $output, $pid ) = $handle->poll_async( key => $key );

    print $output;
}
