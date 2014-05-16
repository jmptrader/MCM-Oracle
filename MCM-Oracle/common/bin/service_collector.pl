#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Secondary;
use Mx::Service;
use Mx::Process;
use Mx::Alert;
use RRDTool::OO;
use POSIX;

my $name = 'service';
 
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
# connect to the secondary monitors
#
my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

#
# get a list of all the configured services
#
my @services = Mx::Service->list( config => $config, logger => $logger );

#
# get the current status of all services
#
my @names = ();
foreach my $service ( @services ) {
    push @{$names[ $service->location ]}, $service->name;
}

my $alert = Mx::Alert->new( name => 'service_down', config => $config, logger => $logger );

while ( 1 ) {
    foreach my $handle ( @handles ) {
        if ( my $names = $names[ $handle->instance ] ) {
            $handle->mservice_async( names => $names );
        }
    }

    @services = ();
    foreach my $handle ( @handles ) {
        if ( my $names = $names[ $handle->instance ] ) {
            push @services, $handle->poll_async;
        }
    }

    my %values = ();
    foreach my $service ( @services ) {
        if ( $service->status eq 'failed' or $service->status eq 'stopped' ) {
            $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $service->name ], item => $service->name ) unless $service->manual;
        }

        next if $service->project;

        foreach my $process ( $service->processes ) {
            if ( $process ) {
                my $label = $process->label;
                next unless $label;
                $label =~ s/:/_/g;
                $values{"cpu_$label"} = $process->pcpu;
                $values{"mem_$label"} = $process->vsz;
                $values{"lwp_$label"} = $process->nlwp;
            }
        }
    }
   
    if ( %values ) {
        unless ( $rrd->update( time => time(), values => \%values ) ) {
            $logger->error("cannot update $rrdfile: " . $rrd->error_message);
        }
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
