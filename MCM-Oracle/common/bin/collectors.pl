#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Secondary;
use Mx::Account;
use Mx::Sybase;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: collectors.pl [ -start ] [ -stop ] [ -restart ] [ -list ] [ -rotate ] [ -name <name> ] [ -help ]

 -start        Start all collectors in the correct order.
 -stop         Stop all collectors in the correct order.
 -restart      Stop and start all collectors in the correct order.
 -list         Show the status of all collectors.
 -rotate       Rotate the logfiles of all collectors.
 -name <name>  Do the action only for this collector.
 -help         Display this text.

EOT
;
    exit;
}

my ($do_start, $do_stop, $do_restart, $do_list, $do_rotate, $name);

GetOptions(
    'start'   => \$do_start,
    'stop'    => \$do_stop,
    'restart' => \$do_restart,
    'list'    => \$do_list,
    'rotate'  => \$do_rotate,
    'name=s'  => \$name,
    'help'    => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'collectors' );

#
# connect to the secondary monitors
#
my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

Mx::Collector->init_disabled_collectors( config => $config ); 

#
# get a list of all the configured collectors 
#
my @collectors = Mx::Collector->list( config => $config, logger => $logger );

@collectors = grep { $_->name eq $name } @collectors if $name;

#
# get the current status of all collectors
#
my @names = ();
foreach my $collector ( @collectors ) {
    push @{$names[ $collector->location ]}, $collector->name;
}

foreach my $handle ( @handles ) {
    if ( my $names = $names[ $handle->instance ] ) {
        $handle->mcollector_async( names => $names );
    }
}

@collectors = ();
foreach my $handle ( @handles ) {
    push @collectors, $handle->poll_async;
}

@collectors = sort { $a->{order} <=> $b->{order} } @collectors;

if ( $do_list ) {
    foreach my $collector ( @collectors ) {
        printf "%-30s (%11s): %s\n", $collector->name, $collector->location, $collector->status;
    }
}

if ( $do_stop or $do_restart ) {
    foreach my $collector (reverse @collectors) {
        next if $collector->is_hard_disabled;

        printf "stopping collector '%s'%s", $collector->name, '.' x (30 - length($collector->name));

        my $rv;
        if ( my $handle = $handles[ $collector->location ] ) {
            $rv = $handle->soaphandle->stop_collector( $collector->name );
        }

        if ( $rv ) {
            printf "stopped\n";
        }
        else {
            printf "failed\n";
        }
    }

    #
    # kill stray connections to the DB (originated from syb_db_perf_collector)
    #
    my $account = Mx::Account->new( name => $config->MX_TSUSER, config => $config, logger => $logger );
    my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );
    $sybase->open();
    $sybase->kill_all( 'master', $account->name );
    $sybase->close();
}

if ( $do_rotate ) {
    foreach my $collector (@collectors) {
        next if $collector->is_hard_disabled;
        $collector->unprepare_for_serialization( config => $config );
        $collector->rotate_log();
    }
}

if ( $do_start or $do_restart ) {
    foreach my $collector (@collectors) {
        next if $collector->is_hard_disabled;

        printf "starting collector '%s'%s", $collector->name, '.' x (30 - length($collector->name));

        my $rv;
        if ( my $handle = $handles[ $collector->location ] ) {
            $rv = $handle->soaphandle->start_collector( $collector->name );
        }

        if ( $rv ) {
            printf "started\n";
        }
        else {
            printf "failed\n";
        }
    }
}

