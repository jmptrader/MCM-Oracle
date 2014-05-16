#!/usr/bin/env perl

use strict;
use warnings;
 
use Mx::Config;
use Mx::Log;
use Mx::Oracle;
use Mx::Account;
use Mx::DBaudit;
use Getopt::Long;
use Date::Calc qw( Delta_Days );


my $SIZE_TRESHOLD = 100;


#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: update_mxtables.pl [ -historize ] [ -force ] [ -growth_rate ] [ -help ]
 
 -historize    Historize the sizes after the update
 -force        Force an update of the already historized sizes
 -growth_rate  Calculate the growth rate of each table
 -help         Display this text
 
EOT
;
    exit;
}
 
#
# process the commandline arguments
#
my ($historize, $force, $growth_rate);
 
GetOptions(
    'historize!'    => \$historize,
    'force!'        => \$force,
    'growth_rate!'  => \$growth_rate,
    'help!'         => \&usage
);

$growth_rate = 1 if $historize;
 
#
# read the configuration files
# 
my $config  = Mx::Config->new;

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mxtables' );

$logger->info("updating table sizes");
 
my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

my @dbs = ( 
  { database => $config->DB_FIN, user => $config->FIN_DBUSER },
  { database => $config->DB_REP, user => $config->REP_DBUSER },
  { database => $config->DB_MON, user => $config->MON_DBUSER },
);

$db_audit->cleanup_mxtable();

foreach my $db ( @dbs ) {
    my $account = Mx::Account->new( name => $db->{user}, config => $config, logger => $logger );

    my $oracle = Mx::Oracle->new( database => $db->{database}, username => $account->name, password => $account->password, logger => $logger, config => $config );

    $oracle->open();
 
    my %tables = ();
    foreach my $table ( $oracle->all_tables() ) {
		my $nr_rows = $oracle->table_size_info( table => $table, no_existence_check => 1 );

		next if $nr_rows < $SIZE_TRESHOLD;

		$tables{$table} = $nr_rows;
    }

    while ( my ( $table, $nr_rows ) = each %tables ) {
        $logger->debug("retrieving space info for table $table");

        my %info = $oracle->table_space_info( table => $table );

        $db_audit->update_mxtable( name => $table, schema => $db->{user}, nr_rows => $nr_rows, %info );
    }

	$oracle->close();

    if ( $growth_rate ) {
        $logger->info("computing growth rates");
        foreach my $table ( keys %tables ) {
            my @result = $db_audit->mxtable_sizes( name => $table, schema => $db->{user} );

            next unless @result > 1;

            my $first_row = $result[-32] || $result[0];
            my $last_row  = $result[-1];

            my ( $timestamp1, $size1 ) = @{$first_row};
            my ( $timestamp2, $size2 ) = @{$last_row};

            my ( $year1, $month1, $day1 ) = $timestamp1 =~ /(\d\d\d\d)(\d\d)(\d\d)/;
            my ( $year2, $month2, $day2 ) = $timestamp2 =~ /(\d\d\d\d)(\d\d)(\d\d)/;

            my $nr_days = Delta_Days( $year1, $month1, $day1, $year2, $month2, $day2 );

            my $growth_rate = ( $size1 && $nr_days ) ? ( ( $size2 - $size1 ) / $size1 * 100 / $nr_days ) : 0;

            $db_audit->update_mxtable_growth_rate( name => $table, growth_rate => $growth_rate );
        }
    }
}

$logger->info("update finished");

if ( $historize ) {
    $logger->info("historizing table sizes");
    $db_audit->historize_mxtable( threshold => $SIZE_TRESHOLD, force => $force );
}
