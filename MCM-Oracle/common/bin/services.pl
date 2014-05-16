#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Service;
use Mx::Secondary;
use Mx::Secondary::Queue;
use Mx::Project;
use Mx::Alert;
use Mx::Util;
use Mx::DBaudit;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: services.pl [ -start ] [ -stop ] [ -restart ] [ -full ] [ -newlogs ] [ -list ] [ -name <name> ] [ -help ] 

 -start       Start all services in the correct order.
 -stop        Stop all services in the correct order.
 -restart     Stop and restart all services in the correct order.
 -full        When stopping or restarting, also kill the remaining mx and java processes.
 -newlogs     Cleanup the logs after stop or before start.
 -list        Show the status of all services.
 -name <name> Do the action only for this service.     
 -help        Display this text.

EOT
;
    exit 1;
}

my ($do_start, $do_stop, $do_restart, $do_full, $do_newlogs, $do_list, $name);

GetOptions(
    'start'      => \$do_start,
    'stop'       => \$do_stop,
    'restart'    => \$do_restart,
    'full'       => \$do_full,
    'newlogs'    => \$do_newlogs,
    'list'       => \$do_list,
    'name=s'     => \$name,
    'help'       => \&usage,
);

my $manual = ( $name ) ? 1 : 0;

unless ( $do_start or $do_stop or $do_restart or $do_list ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'services' );

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#
# connect to the secondary monitors
#
my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

#
# get a list of all the configured services
#
my @all_services = Mx::Service->list( name => $name, config => $config, logger => $logger);

#
# get the current status of all services
#
my @names = ();
foreach my $service ( @all_services ) {
    push @{$names[ $service->location] }, $service->name;
}

my @services = ();
foreach my $handle ( @handles ) {
    next unless $handle;

    if ( my $names = $names[ $handle->instance ] ) {
        push @services, $handle->soaphandle->mservice( names => $names )->paramsall;
    }
}

@services = sort { $a->{order} <=> $b->{order} } @services;

if ( $do_list ) {
    foreach my $service (@services) {
        printf "%-30s: %s\n", $service->name, $service->status;
    }
}

if ( $do_stop or $do_restart ) {
    my $alert = Mx::Alert->new( name => 'service_down', config => $config, logger => $logger );
    $alert->disable();

    my $kill_flag = $config->GLOBAL_SESSION_KILL_FLAG;
    if ( $do_full ) {
        $logger->info("creating global session kill flag ($kill_flag)");
        unless ( open FH, ">$kill_flag" ) {
            $logger->error("cannot create $kill_flag: $!");
        } 
        close(FH);
    }

	my $queue = Mx::Secondary::Queue->new( timeout => 600, logger => $logger );

    map { $queue->add_handle( handle => $_, threshold => 10 ) } @handles;

    foreach my $service ( reverse @services ) {
		my $item_name = ( $service->location ) ? $service->name . '_' . $service->location : $service->name;

		$queue->add_item(
		  name          => $item_name,
		  instance      => $service->location,
		  method        => 'service_action',
		  method_args   => { name => $service->name, action => 'stop' },
		  poll_interval => 3,
		  pre_handler   => sub { printf "stopping service %s on instance %d\n", $service->name, $service->location; },
		  post_handler  => sub { printf "service %s on instance %d is stopped\n", $service->name, $service->location; },
		  fail_handler  => sub { printf "! service %s on instance %d failed\n", $service->name, $service->location; },
		  timeout       => 300
		);
    }

	$queue->run;

    if ( $do_full ) {
        if ( unlink( $kill_flag ) ) {
            $logger->info("global session kill flag cleaned up");
        }
        else {
            $logger->error("cannot remove $kill_flag: $!");
        }
    }
}

if ( $do_full ) {
    map { $_->full_kill_async if $_ } @handles;

    foreach my $handle ( @handles ) {
        next unless $handle;

        my $hostname = $handle->hostname;

        my ( $nr_killed ) = $handle->poll_async;

        $logger->info("$nr_killed processes killed on $hostname");
    }
}

if ( $do_newlogs ) {
    print "cleaning log directory...........................";

    my $workdir = $config->MXENV_ROOT;
    my $tarfile = $workdir . '/logs.tar';

    Mx::Util->tar( tarfile => $tarfile, workdir => $workdir, files => [ 'logs' ], logger => $logger, config => $config );

    if ( -f $tarfile ) {
        if ( Mx::Log->rotate( filename => $tarfile, directory => $workdir, count => 7, compress => 1 ) ) {
            Mx::Util->rmdir( directory => "$workdir/logs", logger => $logger );
            unlink $tarfile;
            print "done\n";
        } 
    }

    print "cleaning RT log directory........................";

    $workdir = $config->MXENV_ROOT . '/interfacesTools/realtime';
    $tarfile = $workdir . '/logs.tar';

    Mx::Util->tar( tarfile => $tarfile, workdir => $workdir, files => [ 'logs' ], logger => $logger, config => $config );

    if ( -f $tarfile ) {
        if ( Mx::Log->rotate( filename => $tarfile, directory => $workdir, count => 7, compress => 1 ) ) {
            Mx::Util->rmdir( directory => "$workdir/logs", logger => $logger );
            unlink $tarfile;
            print "done\n";
        } 
    }
}

if ( $do_start or $do_restart ) {
    ##Force the creation of these logdirs
    my @projects     = qw();
    my $projects_cfg = Mx::Config->new();

    foreach my $project ( @projects ) {
      $projects_cfg->set_project_variables( $project );

      Mx::Log->create_logdir( directory => $projects_cfg->PROJECT_LOGDIR );
    }

    my $exitcode = 0;

	my $queue = Mx::Secondary::Queue->new( logger => $logger );

    map { $queue->add_handle( handle => $_, threshold => 5 ) } @handles;

    foreach my $service (@services) {
        next if ( $service->manual && ! $manual );

		my $item_name = ( $service->location ) ? $service->name . '_' . $service->location : $service->name;

		$queue->add_item(
		  name         => $item_name,
		  instance     => $service->location,
		  method       => 'service_action',
		  method_args  => { name => $service->name, action => 'start' },
		  pre_handler  => sub { printf "starting service %s on instance %d\n", $service->name, $service->location; },
		  post_handler => sub { printf "service %s on instance %d is started\n", $service->name, $service->location; },
		  fail_handler => sub { printf "! service %s on instance %d failed\n", $service->name, $service->location; },
		  dependencies => $service->dependency,
		  timeout      => 300
		);
    }

	$exitcode = $queue->run;

    my $alert = Mx::Alert->new( name => 'service_down', config => $config, logger => $logger );
    $alert->enable();

    exit $exitcode;
}


