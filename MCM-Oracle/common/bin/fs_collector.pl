#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Collector;
use Mx::Filesystem;
use Mx::Alert;
use Mx::Util;
use RRDTool::OO;
use POSIX;
use File::Copy;


my $config = Mx::Config->new();
my $mode   = $ARGV[0];
my $logger = Mx::Log->new( filename => $ARGV[1] );

my $name; my $type;
if ( $mode eq 'local' ) {
    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
    my $hostname    = Mx::Util->hostname();

    my ( $location ) = grep { Mx::Util->hostname( $app_servers[$_] ) eq $hostname } 0..$#app_servers;

    $name = 'app_server_' . $location . '_fs';
    $type = $Mx::Filesystem::TYPE_LOCAL;
}
elsif ( $mode eq 'nfs' ) {
    $name = 'app_server_nfs';
    $type = $Mx::Filesystem::TYPE_NFS;
}
else {
    $logger->logdie("wrong mode ($mode) specified");
}

$logger->info("started in $mode mode");

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

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my $status_alert = Mx::Alert->new( name => 'fs_status', config => $config, logger => $logger ); 
my $usage_alert  = Mx::Alert->new( name => 'fs_usage', config => $config, logger => $logger ); 

my @filesystems = Mx::Filesystem->retrieve_all( type => $type, config => $config, logger => $logger );

while ( 1 ) {
    my %values = ();

    foreach my $filesystem ( @filesystems ) {
        my $name = $filesystem->name;

        unless ( $filesystem->update ) {
            $status_alert->trigger( level => $Mx::Alert::LEVEL_FAIL, item => $name, values => [ $name ] ) if $filesystem->alert;
            next;
        }

        my $percent_used = $filesystem->percent_used;

        if ( $filesystem->alert ) {
            my $level = undef;
            if ( $percent_used > $filesystem->fail_threshold ) {
                $level = $Mx::Alert::LEVEL_FAIL;
            }
            elsif ( $percent_used > $filesystem->warning_threshold ) {
                $level = $Mx::Alert::LEVEL_WARNING;
            }

            $usage_alert->trigger( level => $level, item => $name, values => [ $name, $percent_used ] ) if $level;
        }

        $values{$name} = $percent_used if $filesystem->historize;
    }

    unless ( $rrd->update( time => time(), values => \%values ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
