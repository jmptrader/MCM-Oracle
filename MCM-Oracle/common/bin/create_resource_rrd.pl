#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::ResourcePool;

use Mx::Collector;
use RRDTool::OO;
 
my $name = 'resource';
 
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

my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $resourcepool = Mx::ResourcePool->new( db_audit => $db_audit, logger => $logger, config => $config );

foreach my $resource ( $resourcepool->resources ) {
    push @options, ( data_source => { name => $resource->{name}, type => 'GAUGE' } );
}

push @options, (
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

$rrd->create( @options );
