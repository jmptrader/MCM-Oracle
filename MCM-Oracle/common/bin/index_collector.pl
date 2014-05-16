#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Account;
use Mx::Database::Index;
use Mx::Alert;
use POSIX;

my $name = 'index';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor    = $collector->descriptor;
my $pidfile       = $collector->pidfile;
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

my @dbs = (
  { type => 'DB_FIN', database => $config->DB_FIN, user => $config->FIN_DBUSER },
  { type => 'DB_REP', database => $config->DB_REP, user => $config->REP_DBUSER },
  { type => 'DB_MON', database => $config->DB_MON, user => $config->MON_DBUSER },
);

my %extra_indexes = (); my $murex_indexes;
foreach my $db ( @dbs ) {
    my $account = Mx::Account->new( name => $db->{user}, config => $config, logger => $logger );

    $db->{oracle} = Mx::Oracle->new( database => $db->{database}, username => $account->name, password => $account->password, logger => $logger, config =>
$config );

    $db->{oracle}->open();

	$extra_indexes{ $db->{type} } = Mx::Database::Index->retrieve_extra_indexes( schema => $db->{user}, oracle => $db->{oracle}, config => $config, logger => $logger );

	$db->{missing_extra_indexes_prev} = 0;

	if ( $db->{type} eq 'DB_FIN' ) {
        $murex_indexes = Mx::Database::Index->retrieve_murex_indexes( schema => $db->{user}, oracle => $db->{oracle}, config => $config, logger => $logger );
	    $db->{missing_murex_indexes_prev} = 0;
    }
}

my $alert = Mx::Alert->new( name => 'index_issue', config => $config, logger => $logger );

while ( 1 ) {
    foreach my $db ( @dbs ) {
		my $type = $db->{type};

	    my ( $existing_indexes, $existing_tables ) = Mx::Database::Index->retrieve_existing_indexes( schema => $db->{user}, oracle => $db->{oracle}, config => $config, logger => $logger );

	    $db->{missing_extra_indexes} = 0;
		foreach my $index ( values %{$extra_indexes{ $type }} ) {
            $index->check( existing_indexes => $existing_indexes, existing_tables => $existing_tables ) || $db->{missing_extra_indexes}++;
        }

		my $delta = $db->{missing_extra_indexes} - $db->{missing_extra_indexes_prev};
		if ( $delta > 0 ) {
            $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $delta, 'extra', $db->{user} ], item => $db->{user} );
            $db->{missing_extra_indexes_prev} = $db->{missing_extra_indexes};
        }

		next unless $type eq 'DB_FIN';

	    $db->{missing_murex_indexes} = 0;
        foreach my $index ( values %{$murex_indexes} ) {
            $index->check( existing_indexes => $existing_indexes, existing_tables => $existing_tables ) || $db->{missing_murex_indexes}++;
        }
		
		$delta = $db->{missing_murex_indexes} - $db->{missing_murex_indexes_prev};
		if ( $delta > 0 ) {
            $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $delta, 'murex', $db->{user} ], item => $db->{user} );
            $db->{missing_murex_indexes_prev} = $db->{missing_murex_indexes};
        }
    }

    sleep $poll_interval;
}

foreach my $db ( @dbs ) {
    $db->{oracle}->close;
}

$process->remove_pidfile();
