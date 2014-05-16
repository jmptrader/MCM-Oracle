#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;                                                                                                                                                               
use Mx::Collector;
use Mx::Account;
use Mx::Sybase;
use RRDTool::OO;
 
my $name = 'limits';

my @db_names = qw( DB_FIN DB_REP DB_MON );
 
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

my @options = ();
foreach my $name ( @db_names ) {
    push @options, ( data_source => { name => $name . '_size_used',  type => 'GAUGE' } );
    push @options, ( data_source => { name => $name . '_size_total', type => 'GAUGE' } );
    push @options, ( data_source => { name => $name . '_conn_used',  type => 'GAUGE' } );
    push @options, ( data_source => { name => $name . '_conn_total', type => 'GAUGE' } );
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

