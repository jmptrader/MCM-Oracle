#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::DBaudit;
use Mx::ResourcePool;
use RRDTool::OO;
use POSIX;

my $name = 'resource';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
my $rrdfile       = $collector->rrdfile;
my $poll_interval = $collector->poll_interval;
 
#
# become a daemon
#
my $pid = fork();
exit if $pid;
unless ( defined($pid) ) {
    $logger->logdie("cannot fork: $!");
}

unless ( setsid() ) {
    $logger->logdie("cannot start a new session: $!");
}

#
# create a pidfile
#
my $process = Mx::Process->new( descriptor => $descriptor, logger => $logger, config => $config, light => 1 );
unless ( $process->set_pidfile( $0, $pidfile ) ) {
    $logger->logdie("not running exclusively");
}

Mx::Collector->init_disabled_collectors( config => $config );

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

#
# open a connection to the auditing database
#
my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $resourcepool = Mx::ResourcePool->new( db_audit => $db_audit, logger => $logger, config => $config );

while ( 1 ) {
    my %values = ();
    foreach my $resource ( $resourcepool->resources ) {
        $values{ $resource->{name} } = $resource->{value};
    }

    unless ( $rrd->update( time => time(), values => \%values ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
