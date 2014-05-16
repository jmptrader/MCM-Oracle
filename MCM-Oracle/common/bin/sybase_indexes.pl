#!/usr/bin/env perl

use warnings;
use strict; 

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::Sybase::Index;
use Mx::Process;
use Getopt::Long;

my %RUNNING_PROCESSES = ();
my $MAX_RUNNING       = 5;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: sybase_indexes.pl -create|-check_doubles [ -name indexname] [-database db_name] [ -help ]
		 One of the following 2 options must be provided:
 -create         Create all missing indexes
 -check_doubles  CHECK for double indexes
 		 These arguments are there for filtering:
 -name           Create a specific index name
 -database       Filter based on database e.g DB_FIN, DB_REP, DB_DWH_PHYSICAL
 		 Some nice to have arguments:
 -help           Display this text
 -verbose	 PRINT out log information to STDOUT

EOT
;
    exit;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($create, $name, $db_raw, $check_doubles, $verbose, $create_query);

GetOptions(
'create!'    => \$create,
'check_doubles!'    => \$check_doubles,
'name=s'     => \$name,
'database=s' => \$db_raw,
'verbose!'    => \$verbose,
'create_query=s'    => \$create_query,
'help!'      => \&usage
);

unless ( $create || $check_doubles || $create_query) {
	usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sybase_indexes' );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
#my $sa_sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $sa_account->name, password => $sa_account->password, error_handler => 1, logger => $logger, config => $config );

#
# open the Sybase connection
#
#$sa_sybase->open();
if($create_query){
	my @parameters = split('@', $create_query);
	print "@parameters \n";
		      my $dsquery;
	      if($parameters[0] eq $config->retrieve('DB_DWH_PHYSICAL')){
	      	$dsquery = $config->DSQUERY_DWH;
	      }else{
	      	$dsquery = $config->DSQUERY;
	      }
	      my $sa_sybase  = Mx::Sybase->new( dsquery => $dsquery, database => $parameters[0], username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
				$sa_sybase->open();
	$sa_sybase->query(query => $parameters[1]);
	$sa_sybase->close();
}

my @database_list = ($config->DB_FIN,$config->DB_REP,$config->DB_DWH_PHYSICAL);

my $database_filter;
if(defined $db_raw){
	$database_filter = $config->retrieve("$db_raw");
	@database_list = ();
	push @database_list, $database_filter;
}
my @indexes;
my @indexes_r;
if ($create){
	if ( $name ) {
		$logger->info("Looking for definition of index $name in indexes.cfg");
		if($verbose){print "Looking for definition of index $name in indexes.cfg \n";}
		push @indexes_r, Mx::Sybase::Index->new( name => $name, config => $config, logger => $logger );
	} else { 
		$logger->info("Reading indexes.cfg");
		if($verbose){print "Reading indexes.cfg \n";}
		my ($indexes_ref, $tables_ref) = Mx::Sybase::Index->retrieve_all( logger => $logger, config => $config );
		@indexes_r = @{$indexes_ref};
	}
	if(defined $db_raw ){
		foreach my $index (@indexes_r){
			my $present = 0;
			foreach my $db (@{$index->database}){
				if ($present == 0 && $db eq $database_filter){
					$present = 1;
					push @indexes,$index;
				}
			}
		}
	}else{
		@indexes=@indexes_r;
	}	

# voor iedere db!
	my %present_indexes;
	my %present_tables;
	foreach my $db (@database_list){
			      my $dsquery;
	      if($db eq $config->retrieve('DB_DWH_PHYSICAL')){
	      	$dsquery = $config->DSQUERY_DWH;
	      }else{
	      	$dsquery = $config->DSQUERY;
	      }
	      my $sa_sybase  = Mx::Sybase->new( dsquery => $dsquery, database => $db, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
				$sa_sybase->open();
		my $result = $sa_sybase->query(query => 'select name from sysindexes');
		foreach my $index_name (@{$result}){
			$present_indexes{$db . $index_name->[0]} = 1;
		}
		$result = $sa_sybase->query(query => 'select name from sysobjects where type="U"');
		foreach my $table_name (@{$result}){
			$present_tables{$db . $table_name->[0]} = 1;
		}
		$sa_sybase->close();
	}
	$logger->info("starting script creation of missing indexes");
	if($verbose){print "starting script creation of missing indexes \n";}
	foreach my $index (@indexes){
		
		my @databases = @{$index->database};
		if(defined $db_raw){
			@databases = ();
			push @databases, $database_filter;
		}
		foreach my $db (@databases){
			
			if(defined $present_tables{$db . $index->table} && !defined $present_indexes{$db . $index->name}){
				
				my $index_name = $index->name;
				my $table = $index->table;
				my $fields = $index->columns;
				$logger->info("Creating index $index_name on table $table with fields $fields");
				if($verbose){print "Creating index $index_name on table $table with fields $fields \n";}
				
				my $query = $db . '@' .'create index ' . $index_name . ' on ' . $db . '..' . $table . ' (' . $fields . ')';
				
				
				my $command = "sybase_indexes.pl -create_query '" . $query ."'";

				$logger->info("Launching sub process: $command");
				if($verbose){print "Launching sub process: $command \n";}
				
				my $process = Mx::Process->background_run( command => $command, logger => $logger, config => $config, ignore_child => 1 );

				my $pid = $process->pid;

				$RUNNING_PROCESSES{$pid} = $process;

				my $nr_running_processes = keys %RUNNING_PROCESSES;
				
				while ( $nr_running_processes >= $MAX_RUNNING ) {
					my @dead_pids = ();
					while ( ($pid, $process ) = each %RUNNING_PROCESSES ) {
						next if $process->is_still_running;

						push @dead_pids, $pid;
					}

					foreach my $pid ( @dead_pids ) {
						delete $RUNNING_PROCESSES{$pid};

						$nr_running_processes--;
					}
					
					sleep(30);
				}
				
				
			}
		}
		
	}

}

	my $nr_running_processes = keys %RUNNING_PROCESSES;

	while ( $nr_running_processes > 0 ) {
		my @dead_pids = ();
		while ( my ($pid, $process ) = each %RUNNING_PROCESSES ) {
			next if $process->is_still_running;

			push @dead_pids, $pid;

			$nr_running_processes--;
		}

		foreach my $pid ( @dead_pids ) {
			delete $RUNNING_PROCESSES{$pid};
		}
		
		sleep(30);
	}
	

if ($check_doubles){
	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
#
# New sybase object to ignore error handling and avoid log polution
#
	my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 0, logger => $logger, config => $config );
	$sybase->open();
	Mx::Sybase::Index->check_doubles( sybase => $sybase, logger => $logger, config => $config );
	$sybase->close();
}

exit 0;
