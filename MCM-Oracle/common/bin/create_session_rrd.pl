#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::GenericScript;

use Mx::Collector;
use RRDTool::OO;
 
my $name = 'session2';
 
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

foreach my $mx_scripttype ( Mx::GenericScript->mx_scripttypes ) {
    $mx_scripttype =~ s/ //g;

    foreach my $app_server ( $config->retrieve_as_array('APP_SRV') ) {
        my $label = Mx::Util->hostname( $app_server ) . $mx_scripttype;
        push @options, ( data_source => { name => $label, type => 'GAUGE' } );
    }

    push @options, ( data_source => { name => $mx_scripttype, type => 'GAUGE' } );
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
