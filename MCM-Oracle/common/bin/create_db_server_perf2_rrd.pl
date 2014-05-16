#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;                                                                                                                                                               
use Mx::Collector;
use RRDTool::OO;
 
my $name = 'db_server_perf2';
 
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
      data_source => { name    => 'scpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'wcpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'icpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'physc',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'entc',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'lbusy',
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
      data_source => { name    => 'scpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'wcpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'icpu',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'physc',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'entc',
                       type    => 'GAUGE'
                     },
      data_source => { name    => 'lbusy',
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
