#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Account;
use Mx::Oracle;
use Mx::Alert;
use RRDTool::OO;
use POSIX;

my $name = 'limits';

my @db_names = qw( DB_FIN     DB_REP     DB_MON );
my @db_users = qw( FIN_DBUSER REP_DBUSER MON_DBUSER );
 
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

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my %dbs = ();
while ( my $db_name = shift @db_names ) {
  my $username = shift @db_users;

  my $database = $config->retrieve( $db_name );
  my $user     = $config->retrieve( $username );

  my $account = Mx::Account->new( name => $user, config => $config, logger => $logger );

  my $oracle  = Mx::Oracle->new( database => $database, username => $account->name, password => $account->password, logger => $logger, config => $config );

  $oracle->open();

  $dbs{ $db_name } = $oracle;
}

while ( 1 ) {
    my %values = ();
    while ( my ( $db_name, $oracle ) = each %dbs ) {
        my %size_info = $oracle->size_info();
        my %conn_info = $oracle->connection_info();

        $values{ $db_name . '_size_used' }  = $size_info{used};
        $values{ $db_name . '_size_total' } = $size_info{total};
        $values{ $db_name . '_conn_used' }  = $conn_info{ $oracle->schema };
        $values{ $db_name . '_conn_total' } = $conn_info{total};
    }

    unless ( $rrd->update( time => time(), values => \%values ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();
