package Mx::Sybase::Index2;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Sybase;
use Carp;

our $CATEGORY_PERMANENT = 'permanent';
our $CATEGORY_TEMPORARY = 'temporary';

our $TYPE_UNKNOWN = 'unknown';
our $TYPE_KBC     = 'kbc';
our $TYPE_MUREX   = 'murex';
our $TYPE_OTHER   = 'other';

our $STATUS_UNKNOWN            = 0;
our $STATUS_OK                 = 1;
our $STATUS_TABLE_NOT_PRESENT  = 2;
our $STATUS_INDEX_NOT_PRESENT  = 3;
our $STATUS_COLUMNS_DIFF       = 4;
our $STATUS_UNIQUE_DIFF        = 5;
our $STATUS_CLUSTERED_DIFF     = 6;
our $STATUS_DEFINED            = 7;
our $STATUS_UNDEFINED          = 8;

my %STATUS_DESCRIPTION = (
  $STATUS_UNKNOWN            => 'unknown',
  $STATUS_OK                 => 'ok',
  $STATUS_TABLE_NOT_PRESENT  => 'no table',
  $STATUS_INDEX_NOT_PRESENT  => 'no index',
  $STATUS_COLUMNS_DIFF       => '<> columns',
  $STATUS_UNIQUE_DIFF        => '<> unique',
  $STATUS_CLUSTERED_DIFF     => '<> clustered',
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
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (config)");
    }

    my $sybase;
    unless ( $sybase = $self->{sybase} = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (sybase)");
    }

    my $index_config;
    unless ( $index_config = $args{index_config} ) {
        my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
        $index_config = Mx::Config->new( $index_configfile );
    }

    my $index_ref;
    unless ( $index_ref = $index_config->retrieve("INDEXES.$name") ) {
        $logger->logdie("index '$name' is not defined in the configuration file");
    }

    foreach my $param ( qw( database table columns category unique ) ) {
        unless ( exists $index_ref->{$param} ) {
            $logger->logdie("parameter '$param' for index '$name' is not defined in the configuration file");
        }
        $self->{$param} = $index_ref->{$param};
    }

    return if $self->{table} =~ /^REPBATCH#P[LC]_\d+#/; # let's filter those out to avoid unnecessary warnings

    #
    # validate database
    #
    if ( my $actual_database = $config->retrieve( $self->{database}, 1 ) ) {
        $self->{database} = $actual_database;
    }
    else {
        $logger->warning("undefined database specified for index $name: " . $self->{database});
        return ();
    }

    #
    # apply the database filter
    #
    if ( $args{database} && $args{database} ne $self->{database} ) {
        return ();
    }

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

        my $query = "select name from sysobjects where name like '$sql_tablepattern' and type = 'U'";
    
        my $current_database = $sybase->database;
        if ( $self->{database} ne $current_database ) {
            $sybase->use( $self->{database} );
        }

        my @tables = ();
        if ( my $result = $sybase->query( query => $query, quiet => 1 ) ) {
            @tables = map { $_->[0] } @{$result};
        }
    
        if ( $self->{database} ne $current_database ) {
            $sybase->use( $current_database );
        }

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
    # validate category
    #
    unless ( $self->{category} eq $CATEGORY_PERMANENT or $self->{category} eq $CATEGORY_TEMPORARY ) {
        $logger->logdie("wrong category specified for index $name: " . $self->{category});
    }

    #
    # validate unique
    #
    $self->{unique} = ( $self->{unique} eq 'yes' or $self->{unique} eq 'YES' ) ? 1 : 0;

    #
    # set clustered to reasonable default
    #
    $self->{clustered} = 0;

    $self->{type}      = $TYPE_KBC;
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

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (config)");
    }

    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Sybase index (name)");
    }

    foreach my $param (qw( database table columns unique clustered )) {
        unless ( exists $args{$param} ) {
            $logger->logdie("parameter '$param' for index '$name' is not specified");
        }
        $self->{$param} = $args{$param};
    }

    $self->{compare}   = join ':', ( @{$self->{columns}}, $self->{unique} );
    $self->{timestamp} = $args{timestamp} || undef;
    $self->{type}      = $args{type}   || $TYPE_UNKNOWN;
    $self->{status}    = $args{status} || $STATUS_UNKNOWN;

    if ( $self->{type} eq $TYPE_UNKNOWN && $self->{name} =~ /^KBC_/ ) {
        $self->{type} = $TYPE_KBC;
    }

    bless $self, $class;
}

#-----------------------------#
sub retrieve_existing_indexes {
#-----------------------------#
    my ( $class, %args ) = @_;


    my %indexes = (); my %tables = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("retrieve_existing_indexes: missing argument (config)");
    }

    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("retrieve_existing_indexes: missing argument (sybase)");
    }

    my $database;
    unless ( $database = $args{database} ) {
        $logger->logdie("retrieve_existing_indexes: missing argument (database)");
    }

    my $current_database = $sybase->database;
    if ( $database ne $current_database ) {
        $sybase->use( $database );
    }

    my @tables = ();
    if ( $args{tables} && ref($args{tables}) eq 'ARRAY' ) {
        @tables = @{$args{tables}};
        $logger->debug("retrieving existing indexes for table(s) @tables");
    }
    else {
        $logger->debug("retrieving all existing indexes");
    }

    my $query1 = 'select
      object_name(A.id),
      A.name,
      index_col(object_name(A.id), A.indid, B.colid),
      A.status,
      A.crdate
      from sysindexes A, syscolumns B
      where A.id = B.id
      and B.colid <= A.keycnt';

    my @all_rows = ();
    if ( @tables ) {
        $query1 .= ' and A.id = object_id(?)';

        foreach my $table ( @tables ) {
            if ( my $result = $sybase->query( query => $query1, values => [ $table ] ) ) {
                push @all_rows, @{$result};
            }
        }
    }
    else {
        if ( my $result = $sybase->query( query => $query1 ) ) {
            @all_rows = @{$result};
        }
    }

    my %indexes2 = ();
    foreach my $row ( @all_rows ) {
        next unless $row->[2]; # no column
        next if $row->[0] =~ /^REPBATCH#P[LC]_\d+#/ && ! @tables;

        my ( $table, $name, $column, $status, $timestamp ) = @{$row};

        my $key = $table . ':' . $name;

        if ( $indexes2{$key} ) {
            push @{$indexes2{$key}->{columns}}, $column;
        }
        else {
            $indexes2{$key}->{table}     = $table;
            $indexes2{$key}->{columns}   = [ $column ];
            $indexes2{$key}->{unique}    = ( $status & 0x2 ) ? 1 : 0;
            $indexes2{$key}->{clustered} = ( $status & 0x10 ) ? 1 : 0;
            $indexes2{$key}->{timestamp} = $timestamp;
        }
    }

    my $nr_indexes = 0;
    while ( my ( $key, $value ) = each %indexes2 ) {
        my ( $table, $name ) = split ':', $key;

        $indexes{ $key } = Mx::Sybase::Index2->new(
            name      => $name,
            table     => $value->{table},
            database  => $database,
            columns   => $value->{columns},
            unique    => $value->{unique},
            clustered => $value->{clustered},
            timestamp => $value->{timestamp},
            status    => $STATUS_UNDEFINED,
            config    => $config,
            logger    => $logger
        );

        $nr_indexes++;
    }

    unless ( $args{tables} ) {
        my $query2 = "select name from sysobjects where type = 'U'";

        if ( my $result = $sybase->query( query => $query2 ) ) {
            map { $tables{ $_->[0] } = 1 } @{$result};
        }
    }

    if ( $database ne $current_database ) {
        $sybase->use( $current_database );
    }

    $logger->debug("$nr_indexes indexes found");

    return ( \%indexes, \%tables );
}

#------------------------#
sub retrieve_kbc_indexes {
#------------------------#
    my ( $class, %args ) = @_;


    my %indexes = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("retrieve_config_indexes: missing argument (config)");
    }

    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("retrieve_config_indexes: missing argument (sybase)");
    }

    my $index_configfile = $config->retrieve('INDEX_CONFIGFILE');
    my $index_config     = Mx::Config->new( $index_configfile );

    $logger->debug("scanning the configuration file for indexes");

    my $indexes_ref;
    unless ( $indexes_ref = $index_config->INDEXES ) {
        $logger->logdie("cannot access the indexes section in the configuration file");
    }

    my $current_database = $sybase->database;
    if ( $args{database} && $args{database} ne $current_database ) {
        $sybase->use( $args{database} );
    }

    my $nr_indexes = 0;
    foreach my $name ( keys %{$indexes_ref} ) {
        foreach my $index (  Mx::Sybase::Index2->_new( name => $name, database => $args{database}, sybase => $sybase, config => $config, index_config => $index_config, logger => $logger ) ) {
            my $key = $index->{table} . ':' . $index->{name};

            $indexes{$key} = $index;

            $nr_indexes++; 
        }
    }

    if ( $args{database} && $args{database} ne $current_database ) {
        $sybase->use( $current_database );
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

    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("retrieve_murex_indexes: missing argument (sybase)");
    }

    my $database = $config->DB_FIN;

    my $current_database = $sybase->database;
    if ( $database ne $current_database ) {
        $sybase->use( $database );
    }

    my $query1 = "select name, id from sysobjects where type = 'U'";

    my $query2 = "select
      M_TABNAME,
      M_EXPRESSION
      from RDBMXNDX_DBF
      where M_SERVERTYPE = 'sybase'
      and M_TABNAME not like 'INTERNAL_INDEX_CREATION%'
      and M_TABNAME not like '.%'
      and M_EXPRESSION like 'create %'
      order by M_TABNAME";

    my $query3 = "select name from syscolumns where id = ?";

    my %existing_tables = ();
    if ( my $result = $sybase->query( query => $query1 ) ) {
        foreach my $row ( @{$result} ) {
            my ( $name, $id ) = @{$row};
            my $info = { name => $name, id => $id };

            $name =~ s/_DBF$//;
            push @{$existing_tables{ $name }}, $info;

            $name =~ s/^.+#([^#]+)$/$1/;
            push @{$existing_tables{ $name }}, $info;
        }
    }

    my $nr_indexes = 0;
    if ( my $result = $sybase->query( query => $query2 ) ) {
        my $previous_tabname = ''; my %matching_tables = ();
        foreach my $row ( @{$result} ) {
            my ( $tabname, $expression ) = @{$row};

            if ( $tabname eq $previous_tabname ) {
                next unless %matching_tables;
                keys %matching_tables; # reset hash pointer
            }
            else { 
                $previous_tabname = $tabname;

                %matching_tables = ();
                if ( my $list = $existing_tables{ $tabname } ) {
                    foreach my $table ( @{$list} ) {
                        if ( my $result = $sybase->query( query => $query3, values => [ $table->{id} ], quiet => 1 ) ) {
                            my %columns = ();
                            map { $columns{ $_->[0] } = 1 } @{$result};
                            $matching_tables{ $table->{name} } = \%columns;
                        }
                    }
                }

                $logger->warn("retrieve_murex_indexes: tabname $tabname cannot be matched (tablename) ") unless %matching_tables;
            }

            my $unique; my $clustered; my $columns; my @columns; my $name;
            if ( $expression =~ /^create(\s+unique)?(\s+clustered)?\s+index\s+(\w+)\s+on\s+<<TableName>>\s+\((.+)\)/ ) {
                $unique    = $1 ? 1 : 0;
                $clustered = $2 ? 1 : 0;
                $name      = $3;
                $columns   = $4;
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

                $indexes{ $table . ':' . $name } =  Mx::Sybase::Index2->new(
                    name      => $name,
                    table     => $table,
                    database  => $database,
                    columns   => \@columns,
                    unique    => $unique,
                    clustered => $clustered,
                    type      => $TYPE_MUREX,
                    config    => $config,
                    logger    => $logger
                );

                $nr_indexes++;
            }

            $logger->warn("retrieve_murex_indexes: tabname $tabname cannot be matched (columns: $columns)") unless $match;
        }
    }

    if ( $database ne $current_database ) {
        $sybase->use( $current_database );
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

#    if ( $self->{clustered} != $index->{clustered} ) {
#        $logger->error("check: index $name: clustered property not identical");
#        $self->{status} = $STATUS_CLUSTERED_DIFF;
#        return 0;
#    }

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
    my $database = $self->{database};

    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("drop: missing argument (sybase)");
    }

    $logger->info("dropping index ${table}.${name}");

    my $current_database = $sybase->database;
    if ( $database ne $current_database ) {
        $sybase->use( $database );
    }

    my $statement = "drop index ${table}.${name}";

    if ( $sybase->do( statement => $statement ) ) {
        $logger->info("index ${table}.${name} dropped");
        return 1;
    }

    if ( $database ne $current_database ) {
        $sybase->use( $current_database );
    }
    
    $logger->error("index ${table}.${name} could not be dropped");

    return 0; 
}

#----------#
sub create {
#----------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $name      = $self->{name};
    my $table     = $args{table}    || $self->{table}; # allow to override table
    my $database  = $args{database} || $self->{database}; # allow to override database
    my @columns   = @{$self->{columns}};
    my $unique    = $self->{unique};
    my $clustered = $self->{clustered};

    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("create: missing argument (sybase)");
    }

    $logger->info("creating index ${table}.${name}");

    my $current_database = $sybase->database;
    if ( $database ne $current_database ) {
        $sybase->use( $database );
    }

    my $statement = 'create ';
    $statement .= 'unique ' if $unique;
    $statement .= 'clustered ' if $clustered;
    $statement .= 'index ' . $name . ' on ' . $table . ' (';
    $statement .= ( join ',', @columns );
    $statement .= ')';

    if ( $sybase->do( statement => $statement ) ) {
        $logger->info("index ${table}.${name} created");
        return 1;
    }

    if ( $database ne $current_database ) {
        $sybase->use( $current_database );
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

#------------#
sub database {
#------------#
    my ( $self ) = @_;

    return $self->{database};
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
sub clustered {
#-------------#
    my ( $self ) = @_;

    return $self->{clustered};
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
      0  => $self->{database},
      1  => $self->{table},
      2  => $self->{name},
      3  => ( join ',', @{$self->{columns}} ),
      4  => ( $self->{columns_actual} ? ( join ',', @{$self->{columns_actual}} ) : '' ),
      5  => ( $self->{unique} ? 'YES' : 'NO' ),
      6  => $self->{timestamp},
      7  => $self->{type},
      8  => $STATUS_DESCRIPTION{ $self->{status} },
      DT_RowId => $self->{type} . ':' . $self->{database} . ':' . $self->{table} . ':' . $self->{name}
    };
}

1;
