package Mx::Datamart::Tables;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Mx::Scheduler;
use Mx::Util;
use Mx::Sybase::Index;

my ( $action, $logger, $config, $dm_config, $dm_config_file, $scheduler, $sybase );
my ( $table_name, $column_definitions, $primary_key_definition, $exists );
my ( @column_list, @column_name_list, @table_list, @table_name_list );
my %action = (
  _exec_create_indexes            => \&_exec_create_indexes,
  _exec_create_table              => \&_exec_create_table,
  _exec_create_table_excl_ndx     => \&_exec_create_table_excl_ndx,
  _exec_drop_indexes              => \&_exec_drop_indexes,
  _exec_drop_table                => \&_exec_drop_table,
  _exec_exists_table              => \&_exec_exists_table,
  _exec_initialize                => \&_exec_initialize,
  _exec_list_tables_with_tag      => \&_exec_list_tables_with_tag,
  _exec_list_table_names_with_tag => \&_exec_list_table_names_with_tag,
  _exec_truncate_table            => \&_exec_truncate_table,
  _exec_update_statistics         => \&_exec_update_statistics
);

our $CREATE_INDEXES            = '_exec_create_indexes';
our $CREATE_TABLE              = '_exec_create_table';
our $CREATE_TABLE_EXCL_NDX     = '_exec_create_table_excl_ndx';
our $DROP_INDEXES              = '_exec_drop_indexes';
our $DROP_TABLE                = '_exec_drop_table';
our $EXISTS_TABLE              = '_exec_exists_table';
our $LIST_TABLES_WITH_TAG      = '_exec_list_tables_with_tag';
our $LIST_TABLE_NAMES_WITH_TAG = '_exec_list_table_names_with_tag';
our $INITIALIZE                = '_exec_initialize';
our $TRUNCATE_TABLE            = '_exec_truncate_table';
our $UPDATE_STATISTICS         = '_exec_update_statistics';
our $TAG                       = 'tag';

#-------#
sub new {
#-------#
  my ( $class, %args ) = @_;
  my $self;

  # logger
  $logger = $args{logger} or croak "new - logger argument missing";

  # config
  unless ( $config = $args{config} ) {
    $logger->logdie("new -  config argument missing");
  }
  $dm_config_file =  $config->CONFIGDIR . '/dm_tables.cfg';
  unless ( $dm_config = Mx::Config->new( $dm_config_file )) {
    logger->logdie("new -  cannot create dm_config");
  }

  # sched_js
  unless ( $scheduler =  Mx::Scheduler->new( jobstream => $args{sched_js}, config => $config, logger => $logger )) {
    logger->logdie("new -  cannot create scheduler");
  }

  # sybase
  unless ( $sybase = $args{sybase} ) {
    $logger->debug("new -  sybase argument missing");
  } else {
    unless ( ref($sybase) eq 'Mx::Sybase2') {
      $logger->debug("new - sybase argument is not of type Mx::Sybase2");
    }
  }


  $self->{column_list} = undef; 
  $self->{column_name_list} = undef; 
  $self->{table_list} = undef; 
  $self->{table_name_list} = undef;
  $self->{table_name} = undef;

  if ( $args{table} ) {
    _process( $self, $INITIALIZE, %args );
  }
  
  bless $self, $class;
  return $self;
}

#----------------#
sub create_table {
#----------------#
  my ( $self, %args ) = @_;
  _process( $self, $CREATE_TABLE, %args );
}

#-------------------------#
sub create_table_excl_ndx {
#-------------------------#
  my ( $self, %args ) = @_;
  _process( $self, $CREATE_TABLE_EXCL_NDX, %args );
}

#------------------------#
sub create_table_indexes {
#------------------------#
  my ( $self, %args ) = @_;
  _process( $self, $CREATE_INDEXES, %args );
}

#--------------#
sub drop_table {
#--------------#
  my ( $self, %args ) = @_;
  _process( $self, $DROP_TABLE, %args );
}

#----------------------#
sub drop_table_indexes {
#----------------------#
  my ( $self, %args ) = @_;
  _process( $self, $DROP_INDEXES, %args );
}

#----------------#
sub exists_table {
#----------------#
  my ( $self, %args ) = @_;
  _process( $self, $EXISTS_TABLE, %args );
  return $exists;
}

#------------------#
sub get_table_name {
#------------------#
  my ( $self, %args ) = @_;
  return $self->{table_name};
}

#---------------------#
sub list_column_names {
#---------------------#
  my ( $self, %args ) = @_;
  return @{$self->{column_name_list}};
}

#------------------------#
sub list_tables_with_tag {
#------------------------#
  my ( $self, %args ) = @_;
  _process( $self, $LIST_TABLES_WITH_TAG, %args );
  return @table_list;
}

#-----------------------------#
sub list_table_names_with_tag {
#-----------------------------#
  my ( $self, %args ) = @_;
  _process( $self, $LIST_TABLE_NAMES_WITH_TAG, %args );
  return @table_name_list;
}

#------------------#
sub truncate_table {
#------------------#
  my ( $self, %args ) = @_;
  _process( $self, $TRUNCATE_TABLE, %args );
}

#---------------------#
sub update_statistics {
#---------------------#
  my ( $self, %args ) = @_;
  _process( $self, $UPDATE_STATISTICS, %args );
}


#------------------------#
sub _exec_create_indexes {
#------------------------#
my ( $self, $table_config, %args ) = @_;
  if ( _exec_exists_table( $self, $table_config, %args )) {
    my ( %indexes, %unique, $result, $result_0, $sql_query );
    
    my $config = Mx::Config->new();
    my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
    my $index_config     = Mx::Config->new( $index_configfile );
    my $pre =  "KBC_";
    if(index($table_config->{tag},'TEMP') != -1){
      $pre ="KBC_T_";
     }
    my $counter = 0;
    my $formatted_counter = sprintf( "%02d", $counter );
    my $index_name = "$pre" . "$table_config->{name}" . "_N" . "$formatted_counter";

    my $indexes_ref = $index_config->retrieve('INDEXES');
    
    while( $indexes_ref->{"$index_name"} ){ 
    	my $database = $indexes_ref->{"$index_name"}->{database};
    	$database =~ s/\s//g;
	my @db_raw_list = split ',', $database;
	my %databases = ();
	foreach my $db_raw (@db_raw_list){
  	  $databases{$config->retrieve($db_raw)} = 1;
	}
	if(exists $databases{$sybase->database()}){
          my $if_unique = $indexes_ref->{"$index_name"}->{unique} || 'no';
          $if_unique = lc($if_unique);
          if ( $if_unique eq 'yes' ) {
            $unique{"$index_name"} = 'unique';
          } else {
            $unique{"$index_name"} = '';
          }
    	  my $column_def = $indexes_ref->{"$index_name"}->{columns};
    	  if ( ref $column_def eq 'ARRAY' ) {
            $indexes{"$index_name"} = @$column_def;
          } else {
            $indexes{"$index_name"} = $column_def;
          }
    	}
    	$counter++;
    	my $formatted_counter = sprintf( "%02d", $counter );
    	$index_name = "$pre" . "$table_config->{name}" . "_N" . "$formatted_counter";
    }
  
    $sql_query = "SELECT so.name, si.name, si.keycnt " .
    "FROM sysobjects so " .
    "JOIN sysindexes si " .
      "ON (so.id = si.id) " .
      "where so.name = '$table_name' " .
      "and si.keycnt > 0";
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
       $logger->logdie("exception - cannot execute query - $sql_query");
    }
    my %existing_indexes;
    while ( my @row = $result->next() ) {
      $sql_query = "SELECT ";
      my $count = 1;
      while ( $count < $row[2] ) {
        if ( $count > 1 ) {
          $sql_query = $sql_query . " + ',' + index_col(object_name(id), indid, $count)";
        } else {  		
          $sql_query = $sql_query . "index_col(object_name(id), indid, $count)";
        }  	  
        $count++;
      }  	
      $sql_query = $sql_query . " FROM sysindexes where name = '$row[1]'";
      unless ( $result_0 = $sybase->query( query => $sql_query, logger => $logger ) ) {
        $logger->logdie("exception - cannot execute query - $sql_query");
      }
      my @next = $result_0->next; 
      $existing_indexes{$next[0]} = 1;
    }
  
    my $index_count = -1; 
    foreach my $index_name_raw ( keys %indexes ) {
      my $index_unique = $unique{"$index_name_raw"};
      my $index_columns = $indexes{"$index_name_raw"};
      $index_columns =~ s/ //g;
      if ( exists $existing_indexes{$index_columns} ) {
        ### no action
      } else {
        my $pre =  "KBC_";
        if(index($table_config->{tag},'TEMP') != -1){
          $pre ="KBC_T_";
        }
        my $index_name = $pre . $table_name . '_N' . substr($index_name_raw,-2);

        # drop ix if exist
        $sql_query = "SELECT so.name, si.name " .
          "FROM sysobjects so " .
          "JOIN sysindexes si " .
          "ON (so.id = si.id) " .
          "WHERE si.name = '$index_name'";
        unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
          $logger->logdie("exception - cannot execute query - $sql_query");
        }
        if ( $result->next() ) {
          $sql_query = 'drop index ' . $table_name . '.' . $index_name;
          unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
            $logger->logdie("exception - cannot execute query - $sql_query");
          }
        }
        # create ix 
        $sql_query = 'create ' . $index_unique . ' index ' . $index_name . ' on ' . $table_name . '(' . $index_columns . ')';
        unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
          $logger->logdie("exception - cannot execute query - $sql_query");
        }
      }
    }
  }
}

#----------------------#
sub _exec_create_table {
#----------------------#
  my ( $self, $table_config, %args ) = @_;
  _exec_create_table_excl_ndx( $self, $table_config, %args);
  _exec_create_indexes( $self, $table_config, %args);
}

#-------------------------------#
sub _exec_create_table_excl_ndx {
#-------------------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  _set_column_definitions( $self, $table_config );
  _set_primary_key_definition( $self, $table_config );
  my $sql_query = "if object_id('$table_name') is null execute ('create table $table_name ( $column_definitions $primary_key_definition )')";
  unless ( my $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
}

#----------------------#
sub _exec_drop_indexes {
#----------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );

  my ( $result, $sql_query );
  $sql_query = "SELECT so.name, si.name " .
    "FROM sysobjects so " .
    "JOIN sysindexes si " .
      "ON (so.id = si.id) " .
      "WHERE so.name = '$table_name' and si.name like '%_N[0-9][0-9]'";
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
  while ( my ( @row ) = $result->next() ) { 
    $sql_query = 'drop index ' . $table_name . '.' . $row[1];
    unless ( my $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
  }
}

#--------------------#
sub _exec_drop_table {
#--------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  my $sql_query = "if object_id('$table_name') is not null execute ('drop table $table_name')";
  unless ( my $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
}

#----------------------#
sub _exec_exists_table {
#----------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  my ( $result );
  my $sql_query = "select count(*) from sysobjects where name = '$table_name'";
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
  my @row = $result->next;
  $exists = $row[0];
  if ( $exists == 0 ) {
    $exists = "";
  }
  return $exists;
}

#--------------------#
sub _exec_initialize {
#--------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  _set_column_definitions( $self, $table_config );
}

#------------------------------# 
sub _exec_list_tables_with_tag {
#------------------------------#
  my ( $self, $table_config, %args ) = @_;
}

#-----------------------------------#
sub _exec_list_table_names_with_tag {
#-----------------------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
}

#------------------------#
sub _exec_truncate_table {
#------------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  _set_column_definitions( $self, $table_config );
  _set_primary_key_definition( $self, $table_config );
  my $sql_query = "if object_id('$table_name') is not null execute('truncate table $table_name')";
  unless ( my $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
}

#---------------------------#
sub _exec_update_statistics {
#---------------------------#
  my ( $self, $table_config, %args ) = @_;
  _set_table_name( $self, $table_config, %args );
  my $sql_query = "if object_id('$table_name') is not null execute('update statistics $table_name')";
  unless ( my $result = $sybase->query( query => $sql_query, logger => $logger ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
}


#------------#
sub _process {
#------------#
  my ( $self, $action, %args ) = @_;
  @column_list      = ();
  @column_name_list = ();
  @table_list       = ();
  @table_name_list  = ();
  $table_name       = undef;

  if ( $args{tag} ) {
    $self->{arg_table} = undef;
    $self->{arg_placeholders} = undef;
    _process_tagged_tables( $self, $action, %args );
  } else {
    if ( $args{table} ) {
      $self->{arg_table} = $args{table};
      $self->{arg_placeholders} = $args{placeholders};
      _process_table( $self, $action, %args );
    } else {
      if ( $self->{arg_table} ) {
        $args{table} = $self->{arg_table};
        $args{placeholders} = $self->{arg_placeholders};
        _process_table( $self, $action, %args ); 
      } else {
        $logger->logdie("create_table -  either table or tag argument should exist");
      }
    }
  }
  $self->{column_list}      = [ @column_list ];
  $self->{column_name_list} = [ @column_name_list ];
  $self->{table_list}       = [ @table_list ];
  $self->{table_name_list}  = [ @table_name_list ];
  $self->{table_name}       = $table_name;
}

#------------------#
sub _process_table {
#------------------#
  my ( $self, $action, %args ) = @_;
  # table
  my $table = $args{table};
  #
  my $table_config;
  unless ( $table_config = $dm_config->{config}->{DM_TABLES}->{$table} ) {
    $logger->logdie("create - table not found in config file");
  }
  #
  &{ $action{$action} }( $self, $table_config, %args );
}

#--------------------------#
sub _process_tagged_tables {
#--------------------------#
  my ( $self, $action, %args ) = @_;
  # args_tag;
  my $args_tag =  $args{tag};
  my @args_tag_array = split(/,/, $args_tag);

  #
  foreach my $key ( keys %{$dm_config->{config}->{DM_TABLES}} ) {
    my $tag;
    if ( $tag  = $dm_config->{config}->{DM_TABLES}->{$key}->{$TAG} ) {
      my @tag_array = split(/,/, $tag);
      foreach $tag (@tag_array) {
        $tag =~ s/ //g;
        foreach $args_tag (@args_tag_array) {
          $args_tag =~ s/ //g;
          if ( $tag eq $args_tag ) {
            my $table_config = $dm_config->{config}->{DM_TABLES}->{$key};
            &{ $action{$action} }( $self, $table_config, %args ); 
            push(@table_list , $key);
            push(@table_name_list, $table_name);
          }
        }
      }
    }
  }
}

#---------------------------#
sub _set_column_definitions {
#---------------------------#
  my ( $self, $table_config) = @_;
  my $column_name;
  $column_definitions = '';
  if ( defined $table_config->{column} ) {
    if ( ref $table_config->{column} eq 'ARRAY') {
      my @columns = @{$table_config->{column}};
       foreach my $column ( @columns ) {
        if ( $column_definitions eq '' ) {
          $column_definitions = $column;
        } else {
          $column_definitions = $column_definitions . ', ' . $column;
        }
        $column_name = (split( / /,$column ))[0..0]; 
        push(@column_list, $column);
        push(@column_name_list, $column_name);
      }
    } else {
      $column_definitions = $table_config->{column};
      $column_name = (split( / /,$table_config->{column} ))[0..0];
      push(@column_list, $table_config->{column});
      push(@column_name_list, $column_name);
    }
  }
}

#-------------------------------#
sub _set_primary_key_definition {
#-------------------------------#
  my ( $self, $table_config) = @_;
  $primary_key_definition = '';
  if ( $table_config->{primary_key} ) {
    $primary_key_definition = ', PRIMARY KEY (' . $table_config->{primary_key} . ')'; 
  } 
}

#-------------------#
sub _set_table_name {
#-------------------#
  my ( $self, $table_config, %args ) = @_;
  unless ( $table_name =  $table_config->{name} ) {
    $logger->logdie("create - name not found in config file");
  }

  my $entity = $scheduler->entity_short;
  my $runtype = $scheduler->runtype;
  $table_name =~ s/__ENTITY__/$entity/;
  $table_name =~ s/__RUN__/$runtype/;
  my @placeholders = $table_name =~ /(__[A-Z]*__)/g;
  if ( $#placeholders > -1 ) {
    # placeholders
    my $args_placeholders; 
    unless ( $args_placeholders =  $args{placeholders} ) {
      $logger->logdie("_set_table_name -  cannot create placeholders - for table $table_name");
    }
    my %args_placeholders = split( /,/, $args_placeholders );
    foreach my $placeholder ( @placeholders ) {
      unless ( $args_placeholders{$placeholder} ) {
        $logger->logdie("_set_table_name -  $placeholder placeholder missing");
      }
      $table_name =~ s/$placeholder/$args_placeholders{$placeholder}/g;
    }
  }
}

###
1
