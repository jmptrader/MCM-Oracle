package Mx::Sybase::Index;

use strict;

use Mx::Log;
use Mx::Config;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Alert;
use Carp;
use Switch;


my $config     = Mx::Config->new( );
# Define list of databases in use:
my @database_list = ($config->DB_FIN,$config->DB_REP,$config->DB_DWH);

#
# properties
#
# name
# table
# database
# tableowner
# columns
# sybase
# exists
#

#-------#
sub new {
	#-------#
	my $self;

	my ( $class, %args ) = @_;

	my $logger = $args{logger} or croak 'no logger defined';


	my ($config,$index_config);

	unless ( $config = $args{config} ) {
		$logger->logdie("missing argument in initialisation of Index object (Mx::Config)");
	}
	unless ( ref($config) eq 'Mx::Config' ) {
		$logger->logdie("config argument is not of type Mx::Config");
	}

	if ($args{no_io}) {
		unless ( $self->{name} = $args{name} ) {
			$logger->logdie("missing argument in initialisation of Sybase index (name)");
		}
		$self->{database} = $args{database};
		$self->{table}    = $args{table};
		my $columns = $args{columns};

		my $category = $args{category};

		$self->{tableowner} = $args{tableowner};

		$columns =~ s/\s//g;

		$self->{columns} = [ split ',', $columns ];

		$self->{type} = $args{type} || 'nonclustered';

		$self->{type} =~ s/\s//g;

		$self->{timestamp} = $args{timestamp};

		if(( $self->{name} =~ /^KBC_T_/ ) && $category eq 'temporary'){
			$category = $self->{category} = 'KBC_T';
		}else{
			if($self->{name} =~ /^KBC_/){
				$category = $self->{category} = 'KBC';
			}else{
				$category = $self->{category} = 'MX';
			}
		}

		$self->{exists} = {};

	} else {
		unless ( $index_config = $args{index_config} ) {
			my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
			$logger->debug("new(): Reading from index file $index_configfile.");
			$index_config     = Mx::Config->new( $index_configfile );
		}

		my $name;
		unless ( $name = $self->{name} = $args{name} ) {
			$logger->logdie("missing argument in initialisation of Sybase index (name)");
		}

#get the reference to the correct index name
		my $index_ref;
		unless ( $index_ref = $index_config->retrieve("%INDEXES%$name", 1) ) {
			$logger->error("Sybase index '$name' is not defined in the configuration file.\n Wildcards used? (Entity, run, product)?");
			return;
		}

#sanity checks
#check for doubles in the file
		if ( ref($index_ref) eq 'ARRAY' ) {
			$logger->logdie("index '$name' if defined more then once");
		}

#make the index object
		my $database;
		unless ( $database = $index_ref->{database} ) {
			$logger->error("no database specified for Sybase index '$name'");
			return;
		}

		$self->{database} = [ split ',', $database ];

#translate database reference to real database name from config
		foreach my $db ( @{$self->{database}} ) {
			$db = $config->retrieve($db);
		}

		my $table;
		unless ( $table = $index_ref->{table} ) {
			$logger->error("no table specified for Sybase index '$name'");
			return;
		}
		$self->{table}      = $table;

		my $columns;
		unless ( $columns = $index_ref->{columns} ) {
			$logger->error("no columns specified for Sybase index '$name'");
			return;
		}
		$columns =~ s/\s//g;
		$self->{columns} = [ split ',', $columns ];

		$self->{tableowner} = $config->retrieve('TABLEOWNER');

		my $category;
		unless ( $category = $index_ref->{category} ) {
			$logger->error("no category specified for Sybase index '$name'");
			return;
		}

                $self->{unique} = lc( $index_ref->{unique} ) || 'no'; 

		my $type="";
#set type and overrule category when needed
		switch ( $name ) {
		case (/^KBC_/)   { $type = 'KBC'; }
		case (/^KBC_T_/) { $type = 'KBC'; $category = 'temporary'; }
			else             { $type = 'MX' ; }
		}

		$self->{category} = $category;
		$self->{type}     = $type;

		$self->{exists} = 0;
	}

	bless $self, $class;
}

#--------#
sub new2 {
	#--------#
	my ( $class, %args ) = @_;


	my $logger = $args{logger} or croak 'no logger defined';
	my $self = { logger => $logger };
	foreach my $param (qw( config name table columns type timestamp database)) {
		unless ( exists $args{$param} ) {
			$logger->logdie("new2 : missing argument ($param)");
		}
		$self->{$param} = $args{$param};
	}

	$self->{tableowner} = $args{tableowner} || $self->{config}->retrieve('TABLEOWNER');

	if( $self->{name} =~ /^KBC_T_/ ){
		$self->{category} = 'KBC_T';
	}else{
		$self->{category}   = ( $self->{name} =~ /^KBC_/ ) ? 'KBC' : 'MX';
	}

	bless $self, $class;
}

#----------------#
sub retrieve_all {
	#----------------#
	my ( $class, %args ) = @_;

	my @indexes = ();

	my $logger = $args{logger} or croak 'no logger defined';

	my $config;
	unless ( $config = $args{config} ) {
		$logger->logdie("missing argument (config)");
	}

	my $db_filter = $args{database_filter};

	$logger->debug('scanning the configuration file for indexes');

	my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
	my $index_config     = Mx::Config->new( $index_configfile );

	my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
	my $sa_account = Mx::Account->new( name => $config->MX_TSUSER, config => $config, logger => $logger );
	my $sa_sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $sa_account->name, password => $sa_account->password, error_handler => 1, logger => $logger, config => $config );
	$sa_sybase->open();

	my $indexes_ref;
	unless ( $indexes_ref = $index_config->retrieve('INDEXES') ) {
		$logger->logdie("cannot access the index section in the configuration file");
	}

	my %tables = {};
	my $config_t = Mx::Config->new();


	foreach my $name ( keys %{$indexes_ref} ) {
		my $category = $indexes_ref->{$name}->{category};
		if($category ne 'temporary' || index($name, 'KBC_T_') == -1){
			my $database = $indexes_ref->{$name}->{database};
			$database =~ s/\s//g;
			my @db_raw_list = split ',', $database;
			$database = [];
			my $db_present = 0;
			foreach my $db (@db_raw_list){
				next if ($config_t->retrieve($db) eq "");		
				push @{$database}, $config_t->retrieve($db);
				if ($config_t->retrieve($db) eq $db_filter){
					$db_present = 1;
				}
			}
			if(defined $db_filter){
				$database = [ $db_filter ];
			}
			unless(defined $db_filter && $db_present == 0){
				my $table = $indexes_ref->{$name}->{table};
				my $columns = $indexes_ref->{$name}->{columns};
				my $tableowner = $config->retrieve('TABLEOWNER');
				if ($name =~ /__ENTITY__/ || $name =~ /__RUN__/ || $name =~ /__PRODUCT__/ || $name =~ /__DATE__/) {
					my $index_name = $name;
					my $root_index = Mx::Sybase::Index->new( name => $name, config => $config, index_config => $index_config, logger => $logger );
					my $root_table = $root_index->{table};
					$root_table=~ s/__ENTITY__/__/;
					$root_table=~ s/__RUN__/_/;
					$root_table=~ s/__PRODUCT__/%/;
					$root_table=~ s/__DATE__/%/;
					my %index_object_present;
					foreach my $db (@{$database}){
						if($db eq $config->retrieve('DB_DWH_PHYSICAL')){
							$sa_sybase->use($config->retrieve('DB_DWH'));
						}else{
							$sa_sybase->use($db);
						}
						my $query = "select name from sysobjects where name like \"$root_table\"";
						my $result = $sa_sybase->query( query => $query );
						foreach my $occurence (@$result){
							my $table_name = $occurence->[0];
							my $pre =  "KBC_";
							if($category eq 'temporary' || $name =~ /KBC_T_/){
								$pre ="KBC_T_";
							}
							my $suffix = "_N" . substr($name,-2);
							my $index_name = "$pre" . "$table_name" . "$suffix";
							if( defined $index_object_present{$index_name}){
								my $index = $index_object_present{$index_name};
								push @{$index->database}, $db;
							}else{
								my @dbs = ();
								push @dbs, $db;
								my $index = Mx::Sybase::Index->new( no_io => 'true', name => $index_name, database => \@dbs,
								table => $table_name, columns=> $columns, category => $category, tableowner => $tableowner,
								config => $config, logger => $logger );
								$index_object_present{$index->name} = $index;
								push @indexes, $index;
							}
							$tables{$table_name}++;

						}
					}
				}else{
					my $index = Mx::Sybase::Index->new( no_io => 'true', name => $name, database => $database,
					table => $table, columns=> $columns, category => $category, tableowner => $tableowner,
					config => $config, logger => $logger );
					push @indexes, $index;

					my $table = $index->{table};
					$tables{$table}++;
				}
			}
		}
	}
	$sa_sybase->close();
	my @tables = keys %tables;

	return \@indexes, \@tables;
}
#-------------------------#
sub retrieve_all_for_table{
	#-------------------------#
	my ( $class, %args ) = @_;
	my $logger = $args{logger} or croak 'no logger defined';
	my $table_filter;
	unless ($table_filter = $args{table} ){
		$logger->logdie("Table missing for filtering!");
	}

	my $config;
	unless ( $config = $args{config} ) {
		$logger->logdie("missing argument (config)");
	}

	my @indexes;

	my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
	my $index_config     = Mx::Config->new( $index_configfile );
	my $indexes_ref;
	unless ( $indexes_ref = $index_config->retrieve('INDEXES') ) {
		$logger->logdie("cannot access the index section in the configuration file");
	}
	foreach my $name ( keys %{$indexes_ref} ) {
		if( $indexes_ref->{$name}->{'table'} eq $table_filter){
			my $index = Mx::Sybase::Index->new(name => $name, config => $config, index_config => $index_config, logger => $logger);
			push @indexes,$index;
		}

	}

	return \@indexes;
}


#-------------------------#
sub retrieve_all_existing {
	#-------------------------#
	my ( $class, %args ) = @_;


	my @all_indexes = (); my @tables = ();

	my $logger = $args{logger} or croak 'no logger defined';

	my $config;
	unless ( $config = $args{config} ) {
		$logger->logdie("missing argument (config)");
	}

	my $table_filter = 0;
	my %table_filter_hash;
	if($args{tables}){
		$table_filter = 1;
		foreach my $table (@{$args{tables}}){
			$table_filter_hash{$table} = 1;
		}
	}

	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

	my $db_filter = $args{database_filter};
	my $orig_database_list = \@database_list;
	if(defined $db_filter){
		@database_list = ();
		@database_list = ($db_filter) ;
	}

	my %existing_index_table_hash = ();

	foreach my $db (@database_list){
	if ($db eq $config->DB_DWH){
		$db = $config->DB_DWH_PHYSICAL
	}
	my $dsquery;
	      if($db eq $config->retrieve('DB_DWH_PHYSICAL')){
	      	$dsquery = $config->DSQUERY_DWH;
	      }else{
	      	$dsquery = $config->DSQUERY;
	      }
	      
	# initialize the Sybase connection
	my $sybase  = Mx::Sybase2->new( dsquery => $dsquery, database => $db, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

	my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

	$sybase->open();

		my $query = "select
	object_name(sysindexes.id),
	sysindexes.name,
	index_col(object_name(sysindexes.id), sysindexes.indid, syscolumns.colid),
	sysindexes.crdate
	from sysindexes, syscolumns
	where sysindexes.id = syscolumns.id
	and syscolumns.colid <= sysindexes.keycnt";
		my $result = $sybase->query(query => $query);
		my @rows = $result->all_rows();
		my %index_field_hash = ();
		my %table_index_hash = ();
		my %index_date_hash = ();
		foreach my $row (@rows){

			my $tabname = @{$row}[0];
			# table filter matters
			next if ($table_filter == 1 && !exists $table_filter_hash{$tabname});

			my $index_name = @{$row}[1];
			my $index_field = @{$row}[2];
			my $timestamp = @{$row}[3];

			if(!exists $index_field_hash{$index_name}){
				$index_field_hash{$index_name} = [];
				if($index_field ne '') {push @{$index_field_hash{$index_name}}, $index_field};
			}else{
				if($index_field ne '') {push @{$index_field_hash{$index_name}}, $index_field};
			}
			if (!exists $table_index_hash{$tabname}){
				$table_index_hash{$tabname} = {};
				$table_index_hash{$tabname}->{$index_name} = $index_field_hash{$index_name};
			}else{
				$table_index_hash{$tabname}->{$index_name} = $index_field_hash{$index_name};
			}
# store timestamp
			if($index_name ne '' && $timestamp ne ''){
				$index_date_hash{$index_name} = $timestamp;
			}
		}
		while( my ($k, $v) = each %table_index_hash ) {
			my $table = $k;
			next if $table =~ /^REPBATCH#P[CL]_\d+#$/;
			my @indexes = keys %{$v};
			foreach my $index_name (@indexes){
				my $name = $index_name;
				next unless (index($name, 'REPBATCH')<0);
				my $type = '';
				my $timestamp = $index_date_hash{$name};
				# remove duplciate entries of fields:
				my @uniq_array = do { my %seen; grep { !$seen{$_}++ } @{$index_field_hash{$index_name}} };
				my $columns = join(',',@uniq_array);
				$type =~ s/\s//g;
				if(! defined $db_filter){
					if(exists $existing_index_table_hash{"$name:$table"}){
						my $index = $existing_index_table_hash{"$name:$table"};
						push @{$index->database}, $db;
					}else{
						my $index = Mx::Sybase::Index->new( no_io => 'true', name => $name, table => $table, columns => $columns, type => $type, timestamp => $timestamp, database =>  [ $db ] , config => $config, logger => $logger );
						$existing_index_table_hash{"$name:$table"} = $index;
						push @all_indexes, $index;
						push @tables, $table;
					}
				}else{
				push @all_indexes, Mx::Sybase::Index->new( no_io => 'true', name => $name, table => $table, columns => $columns, type => $type, timestamp => $timestamp, database =>  [ $db ] , config => $config, logger => $logger );
				push @tables,$table;
			}
			}

		}
		$sybase->close();
	}
	
	if(defined $db_filter){
		@database_list = @{$orig_database_list};
	}

	return \@all_indexes, \@tables;
}

#-------------------------#
sub retrieve_all_murex {
	#-------------------------#
	my ( $class, %args ) = @_;

	my @indexes = ();
	my @tables = ();

	my $logger = $args{logger} or croak 'no logger defined';
	my $config;
	unless ( $config = $args{config} ) {
		$logger->logdie("missing argument (config)");
	}

# setup the Sybase account
	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

# initialize the Sybase connection
	my $sybase  = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

	my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

	$sybase->open();

	$sybase->use($config->DB_FIN);

#select all rows with servertype sybase from the murex definition table
	my $query = "select M_TABNAME,M_EXPRESSION from RDBMXNDX_DBF where M_SERVERTYPE = 'sybase' and M_TABNAME not like 'INTERNAL_INDEX_CREATION%'";
	my $result = $sybase->query(query => $query);
	my @rows = $result->all_rows();

#select actual table names from sysobjects
	my $query2 = "select distinct name from sysobjects where type = 'U'";
	my $result = $sybase->query(query => $query2);
	my @rows2  = $result->all_rows();

#select actual table names with their column names
	my $query3 = "SELECT so.name, sc.name FROM syscolumns sc INNER JOIN sysobjects so ON sc.id = so.id";
	my $result = $sybase->query(query => $query3);
	my @rows3  = $result->all_rows();
	my %table_coll_hash = ();
	foreach my $row3 (@rows3){
		if(!exists $table_coll_hash{@{$row3}[0]}){
			$table_coll_hash{@{$row3}[0]} = [];
			push @{$table_coll_hash{@{$row3}[0]}}, @{$row3}[1];
		}else{
			push @{$table_coll_hash{@{$row3}[0]}}, @{$row3}[1];
		}
	}

	my $table;

	foreach my $row (@rows){

		#loop through all the rows of RDBMXNDX_DBF
		my $tabname = @{$row}[0];
		my $expression = @{$row}[1];


		# ignore entries starting with .<EXT> and drop statements
		if( index($tabname,'.') != 0 && index($expression,'drop') == -1){

			#retrieve and match with user table names from sysobjects
			my @matching_tables=();

			foreach my $row2 (@rows2){
				$table = @$row2[0];
				if ( ( $table =~ "#${tabname}_DBF" ) || ($table eq "${tabname}_DBF") || ($table eq "$tabname")) {
					push @matching_tables, $row2;
				}
			}

			my $found=@matching_tables;
			if ( $found == 0 ) {
				next;
			}
			$expression =~ /\(([^)]+)\)/;

			my $columns = $1;
			$columns =~ s/\s//g;

			$expression =~ /index ([^)]+) on/;
			my $index_name = $1;
			$index_name =~ s/\s//g;
			my $database = [];
			# check if columns exists in table
			my %existing_columns;
			foreach my $table_match (@matching_tables){
				my @needed_columns = split ',',$columns;
				my $number_needed = @needed_columns;
				my $number_found  = 0;
				my @rows_in_db = @{$table_coll_hash{@$table_match[0]}};
				my $size = @rows_in_db;
				foreach my $column (@needed_columns){
					foreach my $row (@rows_in_db){
						if ($row eq $column) {
							$number_found += 1;
							last;
						}
					}
				}
				if ( $number_found == $number_needed ) {
					my $index = Mx::Sybase::Index->new(no_io => 'true', name => $index_name, database => [ $config->DB_FIN ],  table => @$table_match[0], columns=> $columns,
					category => 'permanent', tableowner => $config->retrieve('TABLEOWNER'), config => $config, logger => $logger);
					push @indexes, $index;
					push @tables, @$table_match[0];
				} else {
				}
			}


		}

	}
	return \@indexes, \@tables;
}

#---------#
sub check {
	#---------#
	my ( $self, %args ) = @_;

	my $logger = $self->{logger};
	my $name   = $self->{name};
	my $table  = $self->{table};
	my $sybase = $args{sybase};
	my $database = $self->{database};
	my $db_filter = $args{database_filter};

	my $old_db = $sybase->database;


	if(defined $db_filter){
		push @{$database},$db_filter;
	}

	$logger->debug("checking index $name");
	foreach my $db (@{$database}){
		$sybase->use($db);
		if (!($name =~ /__ENTITY__/ || $name =~ /__RUN__/ || $name =~ /__PRODUCT__/ || $name =~ /__DATE__/)){
			my $result = $sybase->query( query => 'select * from sysobjects where name = ?', values => [ $table ] );
			my @rows = $result->all_rows();
			my $row = $rows[0];
			if (defined  @{$row}[0] ) {
				$logger->info("table $table exists");
			} else {
				$logger->info("table $table does not exist (substring?). ");
				${$self->{exists}}{"$db"} = -1;
			}
			$result = $sybase->query( query => 'select * from sysindexes where name = ?', values => [ $name ] );
			@rows = $result->all_rows();
			$row = $rows[0];
			if (defined  @{$row}[0] ) {
				$logger->info("index $name exists");
				${$self->{exists}}{"$db"} = 1;
			} else {
				$logger->info("index $name does not exist");
				${$self->{exists}}{"$db"} = 0;
			}
			if($self->{category} ne 'MX' && ${$self->{exists}}{"$db"} == 1){
				my $query = "select name, keycnt from sysindexes where keycnt > 0 and name = '$name'";
				my $result = $sybase->query(query => $query);
				if($result){
					my @rows = $result->all_rows();
					my $row = $rows[0];
					my $name =@{$row}[0];
					my $keycnt = @{$row}[1];
					my $sql_query = "SELECT name ";
					my $count = 1;
					while ( $count < $keycnt ) {
						if ( $count > 1 ) {
							$sql_query = $sql_query . " + ',' + index_col(object_name(id), indid, $count)";
						} else {
							$sql_query = $sql_query . ", index_col(object_name(id), indid, $count)";
						}
						$count++;
					}
					$sql_query = $sql_query . " FROM sysindexes where name = '$name'";
					unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
						$logger->logdie("exception - cannot execute query - $sql_query");
					}
					@rows = $result->all_rows();
					$row = $rows[0];
					my $defined_columns = @{$row}[1];
					my $temp = join ',',$self->{columns};
					if ($defined_columns ne join ',',$self->{columns}){
						${$self->{exists}}{"$db"} = -2;
					}
				}
			}

		}else{
			$logger->info("index $name contains placeholders, defaulting to does not exist to dynamically assess presence on creation");
			${$self->{exists}}{"$db"} = 0;
		}
	}
	if($old_db ne $sybase->database){
		$sybase->use($old_db);
	}
}

#------------#
sub check_all{
	#------------#

	my %checked_indexes = {};
	my ( $self, %args ) = @_;
	my $logger = $args{logger};
	my $config = $args{config};
	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
	my $sybase  = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
	my $indexes_ref = $args{indexes};
	my @indexes = @{$indexes_ref};
	my $result;
	my %table_exists_map = ();
	my %indexes_db = ();
	my %table_db = ();
	my %index_table =();

	$sybase->open();

	foreach my $db (@database_list){
		my $query = "select name from sysobjects where type=\"U\"";
		$sybase->use($db);
		$result = $sybase->query( query => $query );
		my @rows = $result->all_rows();
		foreach my $row ( @rows ) {
			my ( $table_name ) = @{$row};
			my $key ="$table_name".":"."$db";
			$table_exists_map { $key } = 1;
			$table_db{ $table_name } = $db;
		}
	}

	foreach my $index (@indexes){
		my $name = $index->{name};
		my $table = $index->{table};
		foreach my $db (@{$index->database}){
			$indexes_db{ $name } = $db;
			my $key ="$table".":"."$db";
			if(exists $table_exists_map { $key }){
				$checked_indexes{ "$db.$table.$name" } = 0;
			}else{
				$checked_indexes{ "$db.$table.$name" } = -1;
			}
			$index_table{ "$name.$db" } = $table;
		}
	}

	foreach my $db (@database_list){
		$sybase->use($db);
		my $query = "select name, keycnt from sysindexes where keycnt > 0";
		my $result = $sybase->query(query => $query);
		my @rows = $result->all_rows();
		foreach my $row (@rows){
			my $name =@{$row}[0];
			my $keycnt = @{$row}[1];
			my $sql_query = "SELECT name ";
			my $count = 1;
			while ( $count < $keycnt ) {
				if ( $count > 1 ) {
					$sql_query = $sql_query . " + ',' + index_col(object_name(id), indid, $count)";
				} else {
					$sql_query = $sql_query . ", index_col(object_name(id), indid, $count)";
				}
				$count++;
			}
			$sql_query = $sql_query . " FROM sysindexes where name = '$name'";
			unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
				$logger->logdie("exception - cannot execute query - $sql_query");
			}
			my @rows = $result->all_rows();
			my $row = $rows[0];
			my $index_name = @{$row}[0];
			my $table = $index_table{ "$index_name.$db" };
			$checked_indexes{"$db.$table.$index_name"} = @{$row}[1];
		}
	}
	$sybase->close();
	return \%checked_indexes;

}

#----------#
sub create {
	#----------#
	my ( $self, %args ) = @_;


	my $logger     = $self->{logger};
	my $name       = $self->{name};
	my $table      = $self->{table};
	my $tableowner = $self->{tableowner};
	my @columns    = @{ $self->{columns} };
	#my $sybase     = $args{sybase};
	my $database_arg   = $args{database};
	my $config = Mx::Config->new();

	#my $old_db = $sybase->database;

	my $succes=0;

	my @defined_databases = @{$self->{database}};

	my $present = 0;
	foreach my $db (@defined_databases){
		if($db eq $database_arg){
			$present = 1;
		}
	}
	if($present == 0){
		$logger->info("$database_arg is not defined in indexes.cfg file or RDBMXNDX_DBF for index $name.");
	}


	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
	my $dsquery;
	if($database_arg eq $config->retrieve('DB_DWH_PHYSICAL')){
		$dsquery = $config->DSQUERY_DWH;
	}else{
		$dsquery = $config->DSQUERY;
	}
	my $sybase  = Mx::Sybase2->new( dsquery => $dsquery, database => $database_arg, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
	$sybase->open();

	if ($name =~ /__ENTITY__/ || $name =~ /__RUN__/ || $name =~ /__PRODUCT__/ || $name =~ /__DATE__/) {
		my $root_index_name = $name;
		my $root_table = $table;
		my $tableowner = $tableowner;
		my $category = $self->{category};
		my $columns = $self->{columns};
		$root_table=~ s/__ENTITY__/__/;
		$root_table=~ s/__RUN__/_/;
		$root_table=~ s/__PRODUCT__/%/;
		$root_table=~ s/__DATE__/%/;
		my $query = "select name from sysobjects where name like '$root_table'";
		my $result = $sybase->query( query => $query );
		my @indexes = ();
		my %index_table_map = ();
		my $pre =  "KBC_";
		if($category eq 'temporary' || $name =~ /KBC_T_/){
			$pre ="KBC_T_";
		}
		my $suffix = "_N" . substr($name,-2);
		my $root_index_name = "$pre" . "$root_table" . "$suffix";
		if($result){
			my @rows = $result->all_rows();
			foreach my $occurence (@rows){
				my $table_name = @{$occurence}[0];
				my $index_name = "$pre" . "$table_name" . "$suffix";
				push @indexes, $index_name;
				$index_table_map{$index_name} = $table_name;
			}
		}
		my %existing_indexes = ();
		$query = "select name from sysindexes where name like '$root_index_name'";
		$result = $sybase->query(query => $query);
		if($result){
			my @rows = $result->all_rows();
			foreach my $occurence (@rows){
				$existing_indexes{"@{$occurence}[0]"} = 1;
			}

			foreach my $index_name (@indexes){
				if (!defined $existing_indexes{"$index_name"} ){

					my $columns = join ',', @columns;
                                        my $statement;

                                        if ( $self->{unique} eq 'yes' ) {
                                            $statement = sprintf "create unique index %s on %s.%s(%s)", $index_name, $tableowner, $index_table_map{$index_name}, $columns;
                                        }
                                        else {
					$statement = sprintf "create index %s on %s.%s(%s)", $index_name, $tableowner, $index_table_map{$index_name}, $columns;
                                        }

					$sybase->use($database_arg);
					if ( $sybase->do( statement => $statement ) ) {
						$logger->info("index $index_name created");
						$succes=1;

					}
					else {
						$logger->error("index $index_name already present, not created");

					}
				}
			}
		}
	}else{

		my $columns = join ',', @columns;
                my $statement;
                if ( $self->{unique} eq 'yes' ) {
                    $statement = sprintf "create unique index %s on %s.%s(%s)", $name, $tableowner, $table, $columns;
                }
                else {
		    $statement = sprintf "create index %s on %s.%s(%s)", $name, $tableowner, $table, $columns;
                }
		if(defined ${$self->{exists}}{"$database_arg"} && ${$self->{exists}}{"$database_arg"} == 0){
			$logger->debug("creating index $name");
			if ( $sybase->do( statement => $statement ) ) {
				$logger->info("index $name created");
				$succes=1;

			}
			else{
				$logger->error("index $name cannot be created");

			}
		}
	}
	if($succes ==1){
		return 1;
	}else{
		return 0;
	}
	$sybase->close();
}


#--------#
sub drop {
	#--------#
	my ( $self, %args ) = @_;


	my $logger     = $self->{logger};
	my $name       = $self->{name};
	my $table      = $self->{table};
	my $tableowner = $self->{tableowner};
	#my $sybase     = $args{sybase};
	my $database_arg   = $args{database};
	my $config = Mx::Config->new();

	#my $old_db = $sybase->database;


	$logger->debug("dropping index $name on database $database_arg");
	my @defined_databases = $self->{database};

	my $present = 0;
	foreach my $db (@defined_databases){
		if($db eq $database_arg){
			$present = 1;
		}
	}
	if($present == 0){
		$logger->warn("$database_arg is not defined in indexes.cfg file or RDBMXNDX_DBF. Index is not dropped!");
		return 0;
	}

	my $statement = sprintf "drop index %s.%s",  $table, $name;

	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
	my $dsquery;
	if($database_arg eq $config->retrieve('DB_DWH_PHYSICAL')){
		$dsquery = $config->DSQUERY_DWH;
	}else{
		$dsquery = $config->DSQUERY;
	}
	my $sybase  = Mx::Sybase2->new( dsquery => $dsquery, database => $database_arg, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );
	$sybase->open();


	if ( $sybase->do( statement => $statement ) ) {
		$logger->info("index $name dropped");
		$sybase->close();
		return 1;
	}
	else {
		$logger->error("index $name cannot be dropped");
		$sybase->close();
		return 0;
	}

}

#----------------------#
sub createindexqueries {
	#----------------------#
	my ( $self, %args ) = @_;

	my $logger = $args{logger} or croak 'no logger defined';
	my $config = $args{config} or croak 'no config defined';

	my ( $indexes_ref, $tables_ref ) = $self->retrieve_all( logger => $logger, config => $config );

	my @indexes = @{$indexes_ref};

	my $file = $config->KBC_MXHOME . "/fs/public/odr/rdbschema/createindexqueries.mxres";
	my $fh = IO::File->new( $file, '>' );

	print $fh '<?xml version="1.0"?><!DOCTYPE TableDescriptors><TableDescriptors name="CreateIndexQueries">';

	#sort stuff here...
	@indexes = sort { $a->name cmp $b->name } @indexes;

	my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
	my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_FIN, username => $account->name, password => $account->password, config=> $config, logger => $logger );
	$sybase->open();

	foreach my $index ( @indexes ) {
		my $db_fin = 0;
		foreach my $db (@{$index->database}){
			if($db eq $config->DB_FIN){
				$db_fin = 1;
			}
		}
		next unless $db_fin == 1;
		my @columns = @{ $index->{columns} };
		my $columns = join ',', @columns;
		my $indextable = $index->table;

		my $result="";

		if ( !($index->table =~ "REPBATCH") ) {
			my $query = "select top 1 $columns from $indextable";
			$result = $sybase->query( query => $query );
		} else {
			$logger->warn("Repbatch table. Not performing table exist test.");
			$result="repbatch";
		}

		if ( $result ) {
			#replace the hash characters with slash
			$indextable =~ s/#/\//g;
			#remove _DBF from the table name as Murex is adding this extention automatically in the adaptIndexes step
			$indextable =~ s/_DBF//g;
			print $fh '<TableDescriptor name="' . $indextable . '"><Queries><Query servertype="sybase">create index ' . $index->name . ' on &lt;&lt;TableName&gt;&gt; (' . $columns . ')</Query></Queries></TableDescriptor>';
			print ("Adding index " . $index->name . " on " . $index->table . " (" . $columns . ")<br>\n");
			$logger->info("Adding index " . $index->name . " on " . $index->table . " (" . $columns . ")");
		} else {
			$logger->error("Index " . $index->name . " on " . $index->table . "(" . $columns . ") could not be created. Please check indexes.cfg");
		}
	}

	$sybase->close();
	print $fh '</TableDescriptors>';
	$fh->close;

	return 0;
}

#-------------------#
sub refresh_indexes {
	#-------------------#
	my ( $class, %args ) = @_;


	my $logger  = $args{logger} or croak 'no logger defined';
	my $config  = $args{config};
	my $sybase  = $args{sybase};
	my $library = $args{library};

	$logger->info("refreshing indexes table");

	my $query;
	unless ( $query = $library->query('refresh_indexes') ) {
		$logger->logdie('query with as key refresh_indexes cannot be retrieved from the library');
	}
	my $orig_db = $sybase->database;


	my $mondb_name = $config->MONDB_NAME;
	$query =~ s/__MONDB_NAME__/$mondb_name/;

	if ( $sybase->do( statement => "truncate table $mondb_name..indexes" ) ) {
		$logger->info("indexes table truncated");
	}
	else {
		$logger->logdie("cannot truncate indexes table");
	}


	foreach my $db (@database_list){
		$sybase->use($db);
		if ( my $nr_rows = $sybase->do( statement => $query ) ) {
			$logger->info("$db indexes table refreshed with $nr_rows entries");
		}
		else {
			$logger->logdie("cannot refresh $db indexes table");
		}
	}

	$sybase->use($orig_db);

	return 1;
}

#--------------#
sub nr_indexes {
	#--------------#
	my ( $class, %args ) = @_;


	my $logger  = $args{logger} or croak 'no logger defined';
	my $config  = $args{config};
	my $sybase  = $args{sybase};
	my $library = $args{library};

	my $query;
	unless ( $query = $library->query('count_indexes') ) {
		$logger->logdie('query with as key count_indexes cannot be retrieved from the library');
	}

	my $result;

	my $count = 0;

	my $orig_db = $sybase->database;

	foreach my $db (@database_list){
		$sybase->use($db);
		$result = $sybase->query( query => $query, quiet => 1 );
		$count = $count + $result->[0][0];
	}

	$sybase->use($orig_db);

	return $count;
}

#-----------------------#
sub nr_required_indexes {
	#-----------------------#
	my ( $class, %args ) = @_;


	my $logger  = $args{logger} or croak 'no logger defined';
	my $config  = $args{config};
	my $sybase  = $args{sybase};

	my $mondb_name = $config->MONDB_NAME;

	my $result = $sybase->query( query => "select count(*) from $mondb_name..indexes" );

	my $count = $result->[0][0];

	$logger->info("$count indexes are required");

	return $count;
}

#-------------------#
sub missing_indexes {
	#-------------------#
	my ( $class, %args ) = @_;


	my $logger  = $args{logger} or croak 'no logger defined';
	my $config  = $args{config};
	my $sybase  = $args{sybase};
	my $library = $args{library};

	my $query;
	unless ( $query = $library->query('missing_indexes') ) {
		$logger->logdie('query with as key missing_indexes cannot be retrieved from the library');
	}

	my $mondb_name = $config->MONDB_NAME;
	$query =~ s/__MONDB_NAME__/$mondb_name/;

	my $result ;

	my @indexes = ();

	my $orig_db = $sybase->database;

	foreach my $db (@database_list){
		$sybase->use($db);
		$query =~ s/__DATABASE__/$db/;
		$result = $sybase->query( query => $query, quiet => 1 );
		foreach my $row ( @{$result} ) {
			my ( $name, $table, $database, $index_id, $nr_keys ) = @{$row};
			push @indexes, { name => $name, table => $table, database => $database, index_id => $index_id, nr_keys => $nr_keys }
		}
		$query =~ s/$db/__DATABASE__/;
	}


	return @indexes;
}

#-------------------#
sub check_doubles {
	#-------------------#
	my ( $class, %args ) = @_;

	my $logger  = $args{logger} or croak 'no logger defined';
	my $config  = $args{config};
	my $sybase  = $args{sybase};

	$logger->info("Checking for doubles");
	my $orig_db = $sybase->database;

	my $alert = Mx::Alert->new( name => 'double_index_detected', config => $config, logger => $logger );
	my $alert_needed = 0;
	foreach my $db (@database_list){
		my @tables = $sybase->all_tables(database => $db);
		my @indexes;
		my @doubles = ();
		foreach my $table (@tables){
			my @indexes = $sybase->table_index_info( table => $table, config => $config, logger => $logger, database => $db );
			my %alerted =();
			if(scalar( @indexes ) > 1){
				foreach my $index1 (@indexes){
					my $columns1 =  join(',',$index1->columns);
					foreach my $index2 (@indexes){
						next if $index2->name eq $index1->name;
						my $columns2 = join(',',$index2->columns);
						my ($shortest, $longest, $short_index, $long_index);
						if(length ($columns1) > length ($columns2)){
							$shortest = $columns2;
							$short_index = $index2;
							$longest = $columns1;
							$long_index = $index1;
						}else{
							$shortest = $columns1;
							$short_index = $index1;
							$longest = $columns2;
							$long_index = $index2;
						}
						if($longest =~ /^$shortest/ && $short_index->category eq 'KBC'){
							push @doubles, $long_index;
							push @doubles, $short_index;
							my $name1 = $long_index->name;
							my $name2 = $short_index->name;
							if($alerted{$name1}!=1 && $alerted{$name1} != 1){
								$logger->error( "Possible double: $db $name1($longest) $name2($shortest)");
								$alerted{$name1} = 1;
								$alerted{$name2} = 1;
							}
							$alert_needed = 1;
						}
					}
				}
			}
		}

	}
	if($alert_needed == 1){
		$alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $config->MXENV ], item => "Double indexes" );

	}

	$sybase->use($orig_db);
	$sybase->close();
	return 1;
}

#--------#
sub name {
	#--------#
	my ( $self ) = @_;


	return $self->{name};
}

#---------#
sub table {
	#---------#
	my ( $self ) = @_;


	return $self->{table};
}

#--------------#
sub tableowner {
	#--------------#
	my ( $self ) = @_;


	return $self->{tableowner};
}

#--------#
sub type {
	#--------#
	my ( $self ) = @_;


	return $self->{type};
}

#-------------#
sub timestamp {
	#-------------#
	my ( $self ) = @_;


	return $self->{timestamp};
}

#------------#
sub category {
	#------------#
	my ( $self ) = @_;


	return $self->{category};
}

#-----------#
sub columns {
	#-----------#
	my ( $self ) = @_;


	if ( wantarray ) {
		return @{ $self->{columns} };
	}
	else {
		return( join ',', @{ $self->{columns} } );
	}
}

#--------#
sub database{
	#--------#
	my ( $self ) = @_;

	return $self->{database}
}

#----------#
sub exists {
	#----------#
	my ( $self ) = @_;


	return $self->{exists};
}

1;
