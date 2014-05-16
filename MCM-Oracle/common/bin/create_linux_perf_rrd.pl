#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use RRDTool::OO;

my $name = 'app_server_0_perf';

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'create_rrd' );

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $rrdfile       = $collector->rrdfile;
my $poll_interval = $collector->poll_interval;

if ( -f $rrdfile ) {
    print "RRD file $rrdfile exists already. Remove it first.\n";
}
else {
    my $rrd = RRDTool::OO->new( file => $rrdfile );

    $rrd->create(
      step        => $poll_interval,
      data_source => { name    => 'ucpu_user',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'ucpu_system',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'ucpu_idle',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'ucpu_iowait',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'umem',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'uswap',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'udsk_read',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'udsk_write',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'unet_rx',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'unet_tx',
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

