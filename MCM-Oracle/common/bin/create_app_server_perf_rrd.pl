#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use RRDTool::OO;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: create_app_server_perf_rrd.pl -i <instance> -help

 -i <instance>     The instance number of the application server.
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

unless ( $instance =~ /^\d+$/ ) {
    print "wrong instance number: $instance\n";
    exit 1;
}

my $name = 'app_server_' . $instance . '_perf';

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'create_rrd' );

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $rrdfile       = $collector->rrdfile;
my $hires_rrdfile = $collector->hires_rrdfile;
my $poll_interval = $collector->poll_interval;

if ( -f $rrdfile ) {
    print "RRD file $rrdfile exists already. Remove it first.\n";
}
else {
    my $rrd = RRDTool::OO->new( file => $rrdfile );

    $rrd->create(
      step        => $poll_interval,
      data_source => { name    => 'ucpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'umem',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'udisk',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'unet',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'scpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'smem',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'sdisk',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'snet',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'load',
                       type    => 'GAUGE'
                     },
      archive     => { rows    => 1440,       # DAY, average of 12 samples, so one sample per minute
                       cpoints => 12,
                       cfunc   => 'MAX'
                     },
      archive     => { rows    => 2016,       # WEEK, average of 60 samples, so one sample every 5 minutes
                       cpoints => 60,
                       cfunc   => 'MAX'
                     },
      archive     => { rows    => 1488,       # MONTH, average of 360 samples, so one sample every half hour
                       cpoints => 360,
                       cfunc   => 'MAX'
                     },
      archive     => { rows    => 1460,       # YEAR, average of 4320 samples, so one sample every 6 hours
                       cpoints => 4320,
                       cfunc   => 'MAX'
                     },
    );
}

exit unless $hires_rrdfile;

if ( -f $hires_rrdfile ) {
    print "RRD file $hires_rrdfile exists already. Remove it first.\n";
}
else {
    my $rrd = RRDTool::OO->new( file => $hires_rrdfile );

    $rrd->create(
      step        => $poll_interval,
      data_source => { name    => 'ucpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'umem',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'udisk',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'unet',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'scpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'smem',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'sdisk',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'snet',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'load',
                       type    => 'GAUGE'
                     },
      archive     => { rows    => 17280       # DAY, no sampling
                     },
      archive     => { rows    => 10080,      # WEEK, average of 12 samples, so one sample every minute
                       cpoints => 12,
                       cfunc   => 'MAX'
                     },
      archive     => { rows    => 8928,       # MONTH, average of 60 samples, so one sample every 5 minutes
                       cpoints => 60,
                       cfunc   => 'MAX'
                     },
      archive     => { rows    => 17520,      # YEAR, average of 360 samples, so one sample every half hour
                       cpoints => 360,
                       cfunc   => 'MAX'
                     },
    );
}

