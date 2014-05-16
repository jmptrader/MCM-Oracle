#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;                                                                                                                                                               
use Mx::Collector;
use RRDTool::OO;
 
my $name = 'syb_db_perf';
 
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


$rrd->create(
    step        => $poll_interval,
    data_source => { name    => 'users',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'runnable',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'cpu',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'io',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'net_in',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'net_out',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'reads',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'writes',
                     type    => 'GAUGE'
                   },
    data_source => { name    => 'errors',
                     type    => 'GAUGE'
                   },
    archive     => { rows    => 1440,       # DAY, average of 12 samples, so one sample per minute
                     cpoints => 12,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 2016,       # WEEK, average of 60 samples, so one sample every 5 minutes
                     cpoints => 60,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 1488,       # MONTH, average of 360 samples, so one sample every half hour
                     cpoints => 360,
                     cfunc   => 'AVERAGE'
                   },
    archive     => { rows    => 1460,       # YEAR, average of 4320 samples, so one sample every 6 hours
                     cpoints => 4320,
                     cfunc   => 'AVERAGE'
                   },
);
