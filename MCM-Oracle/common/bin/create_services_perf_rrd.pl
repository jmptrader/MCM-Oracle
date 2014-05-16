#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Service;

use Mx::Collector;
use RRDTool::OO;
 
my $name = 'service';
 
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

foreach my $service ( Mx::Service->list( config => $config, logger => $logger ) ) {
    foreach my $label ( $service->labels ) {
        next unless $label;
        next if $service->project;
        $label =~ s/:/_/g;
        push @options, ( data_source => { name => "cpu_$label", type => 'GAUGE' } );
        push @options, ( data_source => { name => "mem_$label", type => 'GAUGE' } );
        push @options, ( data_source => { name => "lwp_$label", type => 'GAUGE' } );
    }
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
