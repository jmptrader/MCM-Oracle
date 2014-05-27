package Mx::Database::Index;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Oracle;
use Carp;

our $TYPE_UNKNOWN = 'unknown';
our $TYPE_EXTRA   = 'extra';
our $TYPE_MUREX   = 'murex';
our $TYPE_OTHER   = 'other';

our $STATUS_UNKNOWN            = 0;
our $STATUS_OK                 = 1;
our $STATUS_TABLE_NOT_PRESENT  = 2;
our $STATUS_INDEX_NOT_PRESENT  = 3;
our $STATUS_COLUMNS_DIFF       = 4;
our $STATUS_UNIQUE_DIFF        = 5;
our $STATUS_DEFINED            = 6;
our $STATUS_UNDEFINED          = 7;

my %STATUS_DESCRIPTION = (
  $STATUS_UNKNOWN            => 'unknown',
  $STATUS_OK                 => 'ok',
  $STATUS_TABLE_NOT_PRESENT  => 'no table',
  $STATUS_INDEX_NOT_PRESENT  => 'no index',
  $STATUS_COLUMNS_DIFF       => '<> columns',
  $STATUS_UNIQUE_DIFF        => '<> unique',
  $STATUS_DEFINED            => 'defined',
  $STATUS_UNDEFINED          => 'undefined'
);

#--------#
sub _new {
#--------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (config)");
    }

    my $index_config;
    unless ( $index_config = $args{index_config} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (index_config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (oracle)");
    }

    my $index_ref;
    unless ( $index_ref = $index_config->retrieve("INDEXES.$name") ) {
        $logger->logdie("index '$name' is not defined in the configuration file");
    }

    foreach my $param ( qw( schema table columns unique ) ) {
        unless ( exists $index_ref->{$param} ) {
            $logger->logdie("parameter '$param' for index '$name' is not defined in the configuration file");
        }
        $self->{$param} = $index_ref->{$param};
    }

	SWITCH: {
	  $self->{schema} eq 'DB_FIN' && do { $self->{schema} = $config->FIN_DBUSER; last SWITCH; };
	  $self->{schema} eq 'DB_REP' && do { $self->{schema} = $config->REP_DBUSER; last SWITCH; };
	  $self->{schema} eq 'DB_MON' && do { $self->{schema} = $config->MON_DBUSER; last SWITCH; };
    }

	if ( $args{schema} && $self->{schema} ne $args{schema} ) {
		return ();
    }

    return if $self->{table} =~ /^REPBATCH#P[LC]_\d+#/; # let's filter those out to avoid unnecessary warnings

    #
    # validate table
    #
    if ( $self->{table} =~ /__ENTITY__/ || $self->{table} =~ /__RUN__/ || $self->{table} =~ /__PRODUCT__/ || $self->{table} =~ /__DATE__/ ) {
        my $sql_tablepattern = $self->{table};
        $sql_tablepattern =~ s/__ENTITY__/__/;
        $sql_tablepattern =~ s/__RUN__/_/;
        $sql_tablepattern =~ s/__PRODUCT__/%/;
        $sql_tablepattern =~ s/__DATE__/%/;

        my $regex_tablepattern = $self->{table};
        $regex_tablepattern =~ s/__ENTITY__/([A-Z][A-Z0-9])/;
        $regex_tablepattern =~ s/__RUN__/([O1VXN])/;
        $regex_tablepattern =~ s/__PRODUCT__/(\\w+)/;
        $regex_tablepattern =~ s/__DATE__/(\\d+)/;

        my $query = "select table_name from dba_tables where owner = ? and table_name like '$sql_tablepattern'";
    
        my $result = $oracle->query( query => $query, values => [ $self->{schema} ], quiet => 1 );

        my @tables = map { $_->[0] } $result->all_rows;

        unless ( @tables ) {
            $logger->warn("index $name cannot be matched to any existing table");
            return ();
        }

        my @names = ();
        foreach my $table ( @tables ) {
            my @matches = $table =~ /^$regex_tablepattern$/;
            my $name = $self->{name};
            foreach my $match ( @matches ) {
                $name =~ s/(__[^_]+__)/$match/;
            }
            push @names, $name;
        }

        $logger->debug("name " . $self->{name} . " extended to: @names"); 
        $logger->debug("table " . $self->{table} . " extended to: @tables");

        $self->{name}  = \@names;
        $self->{table} = \@tables;
    }

    #
    # validate columns
    #
    $self->{columns} =~ s/\s//g;
    $self->{columns} = [ split ',', $self->{columns} ];

    #
    # validate unique
    #
    $self->{unique} = ( $self->{unique} eq 'yes' or $self->{unique} eq 'YES' ) ? 1 : 0;

    $self->{type}      = $TYPE_EXTRA;
    $self->{timestamp} = undef;
    $self->{compare}   = join ':', ( @{$self->{columns}}, $self->{unique} );
    $self->{status}    = $STATUS_UNKNOWN;

    my @indexes = ();
    if ( ref($self->{name}) eq 'ARRAY' ) {
	while ( my $name = shift @{$self->{name}} ) {
            my $table = shift @{$self->{table}};
        
            my $index = {};
            %{$index} = %{$self};

            $index->{name}  = $name;
            $index->{table} = $table;

            $logger->debug("index $name initialized");

            bless $index, $class;

            push @indexes, $index;
        }
    }
    else {
        $logger->debug("index $name initialized");

        bless $self, $class;

        push @indexes, $self;
    }

    return @indexes;
}

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of database index (name)");
    }

    foreach my $param (qw( schema table columns unique type )) {
        unless ( exists $args{$param} ) {
            $logger->logdie("parameter '$param' for index '$name' is not specified");
        }
        $self->{$param} = $args{$param};
    }

    $self->{compare}   = join ':', ( @{$self->{columns}}, $self->{unique} );
    $self->{timestamp} = $args{timestamp} || undef;
    $self->{status}    = $args{status} || $STATUS_UNKNOWN;

    bless $self, $class;
}

#-----------------------------#
sub retrieve_existing_indexes {
#-----------------------------#
    my ( $class, %args ) = @_;


    my %indexes = (); my %tables = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("retrieve_existing_indexes: missing argument (oracle)");
    }

    my $schema;
    unless ( $schema = $args{schema} ) {
        $logger->logdie("retrieve_existing_indexes: missing argument (schema)");
    }

    my @tables = ();
    if ( $args{tables} && ref($args{tables}) eq 'ARRAY' ) {
        @tables = @{$args{tables}};
        $logger->debug("retrieving existing indexes for table(s) @tables");
    }
    else {
        $logger->debug("retrieving all existing indexes");
    }

    my $query1 = "select
      A.table_name,
      A.index_name,
      A.uniqueness,
      B.column_name,
      B.column_position,
	  to_char( C.created, 'YYYY-MM-DD HH24:MI:SS' )
      from all_indexes A 
		inner join all_objects C on ( C.object_type = 'INDEX' and A.index_name = C.object_name )
	    right outer join all_ind_columns B on ( A.table_name = B.table_name and A.index_name = B.index_name )
      where A.table_owner = ?";

    my @all_rows = ();
    if ( @tables ) {
        $query1 .= ' and A.table_name = ?';

        foreach my $table ( @tables ) {
            if ( my $result = $oracle->query( query => $query1, values => [ $schema, $table ], quiet => 1 ) ) {
                push @all_rows, $result->all_rows;
            }
        }
    }
    else {
        if ( my $result = $oracle->query( query => $query1, values => [ $schema ], quiet => 1 ) ) {
            @all_rows = $result->all_rows;
        }
    }

    my %indexes2 = ();
    foreach my $row ( @all_rows ) {
        next if $row->[0] =~ /^REPBATCH#P[LC]_\d+#/ && ! @tables;

        my ( $table, $name, $unique, $column, $position, $timestamp ) = @{$row};

        my $key = $table . ':' . $name;

        if ( $indexes2{$key} ) {
            push @{$indexes2{$key}->{columns}}, $column;
        }
        else {
            $indexes2{$key}->{table}     = $table;
            $indexes2{$key}->{columns}   = [ $column ];
            $indexes2{$key}->{unique}    = ( $unique eq 'UNIQUE' ) ? 1 : 0;
            $indexes2{$key}->{timestamp} = $timestamp;
        }
    }

    my $nr_indexes = 0;
    while ( my ( $key, $value ) = each %indexes2 ) {
        my ( $table, $name ) = split ':', $key;

        $indexes{ $key } = Mx::Database::Index->new(
            name      => $name,
            table     => $value->{table},
            schema    => $schema,
            columns   => $value->{columns},
            unique    => $value->{unique},
            type      => $TYPE_UNKNOWN,
            timestamp => $value->{timestamp},
            status    => $STATUS_UNDEFINED,
            logger    => $logger
        );

        $nr_indexes++;
    }

    unless ( $args{tables} ) {
		my @all_tables = $oracle->all_tables( schema => $schema );
        map { $tables{$_} = 1 } @all_tables;
    }

    $logger->debug("$nr_indexes indexes found");

    return ( \%indexes, \%tables );
}

#--------------------------#
sub retrieve_extra_indexes {
#--------------------------#
    my ( $class, %args ) = @_;


    my %indexes = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("retrieve_config_indexes: missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("retrieve_config_indexes: missing argument (oracle)");
    }

    my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
    my $index_config     = Mx::Config->new( $index_configfile );

    $logger->debug("scanning the configuration file for indexes");

    my $indexes_ref;
    unless ( $indexes_ref = $index_config->INDEXES ) {
        $logger->logdie("cannot access the indexes section in the configuration file");
    }

    my $nr_indexes = 0;
    foreach my $name ( keys %{$indexes_ref} ) {
        foreach my $index (  Mx::Database::Index->_new( name => $name, schema => $args{schema}, oracle => $oracle, config => $config, index_config => $index_config, logger => $logger ) ) {
            my $key = $index->{table} . ':' . $index->{name};

            $indexes{$key} = $index;

            $nr_indexes++; 
        }
    }

    $logger->debug("$nr_indexes indexes found");

    return \%indexes;
}

#--------------------------#
sub retrieve_murex_indexes {
#--------------------------#
    my ( $class, %args ) = @_;


    my %indexes = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("retrieve_murex_indexes: missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("retrieve_murex_indexes: missing argument (oracle)");
    }

	my $schema = $config->FIN_DBUSER;

    my $query = "select
      M_TABNAME,
      M_EXPRESSION
      from RDBMXNDX_DBF
      where M_SERVERTYPE = 'oracle'
      and M_TABNAME not like 'INTERNAL_INDEX_CREATION%'
      and M_TABNAME not like '.%'
      and M_EXPRESSION like 'create %'
      order by M_TABNAME";

    my %existing_tables = ();
	foreach my $tablename ( $oracle->all_tables( schema => $schema ) ) {
        my $info = { name => $tablename };

        $tablename =~ s/_DBF$//;
        push @{$existing_tables{ $tablename }}, $info;

        $tablename =~ s/^.+#([^#]+)$/$1/;
        push @{$existing_tables{ $tablename }}, $info;
    }


    my $nr_indexes = 0;
    my $previous_tabname = ''; my %matching_tables = ();

	my $result = $oracle->query( query => $query );

	while ( my ( $tabname, $expression ) = $result->next ) {
        if ( $tabname eq $previous_tabname ) {
            next unless %matching_tables;
            keys %matching_tables; # reset hash pointer
        }
        else {
            $previous_tabname = $tabname;

            %matching_tables = ();
            if ( my $list = $existing_tables{ $tabname } ) {
                foreach my $table ( @{$list} ) {
					my %columns;
					my @columns = $oracle->table_column_info( table => $table->{name}, schema => $schema );
                    map { $columns{ $_->{name} } = 1 } @columns;
                    $matching_tables{ $table->{name} } = \%columns;
                }

                $logger->warn("retrieve_murex_indexes: tabname $tabname cannot be matched (tablename) ") unless %matching_tables;
            }

            my $unique; my $columns; my @columns; my $name;
            if ( $expression =~ /^create(\s+unique)?\s+index\s+<<IndexName>>(\w+)\s+on\s+<<TableName>>\s+\((.+)\)/ ) {
                $unique    = $1 ? 1 : 0;
                $name      = $tabname . $2;
                $columns   = $3;
                $columns   =~ s/\s//g;
                @columns   = split ',', $columns;
            }
            else {
                $logger->error("retrieve_murex_indexes: expression cannot be parsed: $expression");
                next;
            }

            my $match = 0;
TABLE:      while ( my ( $table, $columns_ref ) = each %matching_tables ) {
                foreach my $column ( @columns ) {
                    unless( $columns_ref->{$column} ) {
                        $logger->warn("retrieve_murex_indexes: column $column not present in table $table");
                        next TABLE;
                    }
                }

                $match++;
             
                $logger->debug("retrieve_murex_indexes: tabname $tabname matches against table $table (columns: $columns)");

                $indexes{ $table . ':' . $name } =  Mx::Database::Index->new(
                    name      => $name,
                    table     => $table,
                    schema    => $schema,
                    columns   => \@columns,
                    unique    => $unique,
                    type      => $TYPE_MUREX,
                    logger    => $logger
                );

                $nr_indexes++;
            }

            $logger->warn("retrieve_murex_indexes: tabname $tabname cannot be matched (columns: $columns)") unless $match;
        }
    }

    $logger->debug("$nr_indexes indexes found");

    return \%indexes;
}

#---------#
sub check {
#---------#
    my ( $self, %args ) =  @_;


    my $logger = $self->{logger};
    my $name   = $self->{name};
    my $table  = $self->{table};

    my $existing_tables;
    unless ( $existing_tables = $args{existing_tables} ) {
        $logger->logdie("check: missing argument (existing_tables)");
    }

    my $existing_indexes;
    unless ( $existing_indexes = $args{existing_indexes} ) {
        $logger->logdie("check: missing argument (existing_indexes)");
    }

    unless ( $existing_tables->{$table} ) {
        $logger->warn("check: index $name: table $table does not exist");
        $self->{status} = $STATUS_TABLE_NOT_PRESENT;
        return 0;
    }

    my $index; 
    unless ( $index = $existing_indexes->{ $table . ':' . $name } ) {
        $logger->error("check: index $name does not exist");
        $self->{status} = $STATUS_INDEX_NOT_PRESENT;
        return 0;
    }

    $self->{timestamp} = $index->{timestamp};
    $index->{status}   = $STATUS_DEFINED;

    if ( $self->{compare} eq $index->{compare} ) {
        $self->{status} = $STATUS_OK;
        return 1;
    }

    my $expected_columns = join ',', @{$self->{columns}};
    my $actual_columns   = join ',', @{$index->{columns}};

    if ( $expected_columns ne $actual_columns ) {
        $logger->error("check: index $name\nexpected columns: $expected_columns\nactual columns: $actual_columns");
        $self->{status} = $STATUS_COLUMNS_DIFF;
        $self->{columns_actual} = $index->{columns};
        return 0;
    }

    if ( $self->{unique} != $index->{unique} ) {
        $logger->error("check: index $name: unique property not identical");
        $self->{status} = $STATUS_UNIQUE_DIFF;
        return 0;
    }

    $self->{status} = $STATUS_UNKNOWN;

    return 0;
}

#--------#
sub drop {
#--------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $name     = $self->{name};
    my $table    = $self->{table};

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("drop: missing argument (oracle)");
    }

    $logger->info("dropping index ${table}.${name}");

    my $statement = "drop index ${name}";

    if ( $oracle->do( statement => $statement ) ) {
        $logger->info("index ${table}.${name} dropped");
        return 1;
    }
    
    $logger->error("index ${table}.${name} could not be dropped");

    return 0; 
}

#----------#
sub create {
#----------#
    my ( $self, %args ) = @_;


    my $logger  = $self->{logger};
    my $name    = $self->{name};
    my $table   = $args{table} || $self->{table}; # allow to override table
    my @columns = @{$self->{columns}};
    my $unique  = $self->{unique};

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("create: missing argument (oracle)");
    }

    $logger->info("creating index ${table}.${name}");

    my $statement = 'create ';
    $statement .= 'unique ' if $unique;
    $statement .= 'index ' . $name . ' on ' . $table . ' (';
    $statement .= ( join ',', @columns );
    $statement .= ')';

    if ( $oracle->do( statement => $statement ) ) {
        $logger->info("index ${table}.${name} created");
        return 1;
    }

    $logger->error("index ${table}.${name} could not be created");

    return 0;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#----------#
sub schema {
#----------#
    my ( $self ) = @_;

    return $self->{schema};
}

#---------#
sub table {
#---------#
    my ( $self ) = @_;

    return $self->{table};
}

#-----------#
sub columns {
#-----------#
    my ( $self ) = @_;

    return @{$self->{columns}};
}

#----------#
sub unique {
#----------#
    my ( $self ) = @_;

    return $self->{unique};
}

#-------------#
sub timestamp {
#-------------#
    my ( $self ) = @_;

    return $self->{timestamp};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;

    return $self->{type};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;

    return $self->{status};
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;


    return {
      0  => $self->{schema},
      1  => $self->{table},
      2  => $self->{name},
      3  => ( join ',', @{$self->{columns}} ),
      4  => ( $self->{columns_actual} ? ( join ',', @{$self->{columns_actual}} ) : '' ),
      5  => ( $self->{unique} ? 'YES' : 'NO' ),
      6  => $self->{timestamp},
      7  => $self->{type},
      8  => $STATUS_DESCRIPTION{ $self->{status} },
      DT_RowId => $self->{type} . ':' . $self->{schema} . ':' . $self->{table} . ':' . $self->{name}
    };
}

1;
