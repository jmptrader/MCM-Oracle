#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Filesystem;
use RRDTool::OO;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: create_app_server_fs_rrd.pl -i <instance> -help

 -i <instance>     The instance number of the application server or the string 'nfs'.
 -help             Display this text.

EOT
;
    exit;
}

my ($instance);

GetOptions(
    'i=s' => \$instance
);

unless ( defined $instance ) {
    usage();
}

unless ( $instance eq 'nfs' or $instance =~ /^\d+$/ ) {
    print "wrong instance number: $instance\n";
    exit 1;
}

my $name; my $type;
if ( $instance eq 'nfs' ) {
    $name = 'app_server_nfs';
    $type = $Mx::Filesystem::TYPE_NFS;
}
#elsif ( $instance == 0 ) {
#    $name = 'app_server_0_fs';
#    $type = $Mx::Filesystem::TYPE_LOCAL_LINUX;
#}
else {
    $name = 'app_server_' . $instance . '_fs';
    $type = $Mx::Filesystem::TYPE_LOCAL_SOLARIS;
}

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'create_rrd' );

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $rrdfile       = $collector->rrdfile;
my $poll_interval = $collector->poll_interval;

if ( -f $rrdfile ) {
    print "RRD file $rrdfile exists already. Remove it first.\n";
    exit;
}

my $rrd = RRDTool::OO->new( file => $rrdfile );

my @options = ( step => $poll_interval );

foreach my $filesystem ( Mx::Filesystem->retrieve_all( type => $type, historize => 1, logger => $logger, config => $config ) ) {
    push @options, ( data_source => { name => $filesystem->name, type => 'GAUGE' } );
}

push @options, (
    archive     => { rows    => 288,       # DAY, average of 5 samples, so one sample per 5 minutes
                     cpoints => 5,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 168,       # WEEK, average of 60 samples, so one sample every hour
                     cpoints => 60,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 186,       # MONTH, average of 240 samples, so one sample every 4 hours
                     cpoints => 240,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 365,       # YEAR, average of 1440 samples, so one sample every day
                     cpoints => 1440,
                     cfunc   => 'AVERAGE'
                   }
);

$rrd->create( @options );

