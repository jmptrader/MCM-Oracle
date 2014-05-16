package Mx::Auth::DB;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Account;
use Mx::Oracle;
use Mx::Database::ResultSet;
use Mx::DBaudit;
use Mx::SQLLibrary;
use Storable qw(nfreeze thaw);
use Carp;

my %START_ID = (
  'users'        => 1,
  'groups'       => 10001,
  'environments' => 1,
  'rights'       => 1,
); 

my @TABLES = qw( users groups environments rights user_group user_group_right );

my %LIBRARY_CACHE = ();

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger; my $config; my $oracle;
    if ( my $db_audit = $args{db_audit} ) {
        $logger = $db_audit->{logger};
        $config = $db_audit->{config};
        $oracle = $db_audit->{oracle};
        $oracle = $oracle->clone;
    }
    else {
        $logger = $args{logger} or croak 'no logger defined.';

        unless ( $config = $args{config} ) {
            $logger->logdie("missing argument in initialisation of auth db (config)");
        }

        my $account = Mx::Account->new( name => $config->AUTH_DBUSER, config => $config, logger => $logger );

        $oracle = Mx::Oracle->new( database => $config->DB_AUTH, username => $account->name, password => $account->password, logger => $logger, config => $config );

        unless ( $oracle->open() ) {
            $logger->error("cannot connect to the authorization database");
            return;
        }
    }

    my $sql_library_file = $config->SQLDIR . '/auth.sql';
    $self->{library} = Mx::SQLLibrary->new( file => $sql_library_file, logger => $logger );

    $self->{logger} = $logger;
    $self->{config} = $config;
    $self->{oracle} = $oracle;

    $logger->info("connected to the authorization database");

    bless $self, $class;
}

#---------#
sub query {
#---------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $query_key  = $args{query_key};
    my $values     = $args{values};

    my $query = $LIBRARY_CACHE{$query_key};
    unless ( $query ) {
        unless ( $query = $self->{library}->query( $query_key ) ) {
            $logger->logdie('query with as key $query_key cannot be retrieved from the library');
        }
        $LIBRARY_CACHE{$query_key} = $query;
    }
    $self->{oracle}->query( query => $query, values => $values );
}

#------#
sub do {
#------#
    my ( $self, %args ) = @_;


    my $logger        = $self->{logger};
    my $statement_key = $args{statement_key};
    my $values        = $args{values};
    my $replicate     = ( exists $args{replicate} ) ? $args{replicate} : 1;

    unless ( ref( $values ) eq 'ARRAY' ) {
        $values = thaw( $values );
    }

    my $statement = $LIBRARY_CACHE{$statement_key};
    unless ( $statement ) {
        unless ( $statement = $self->{library}->query( $statement_key ) ) {
            $logger->logdie('query with as key $statement_key cannot be retrieved from the library');
        }
        $LIBRARY_CACHE{$statement_key} = $statement;
    }
    
    my $nr_rows = $self->{oracle}->do( statement => $statement, values => $values );

    if ( $nr_rows && $replicate ) {
        my $svalues   = nfreeze( $values );
        my $sync_flag = 'N';

        $self->{oracle}->do( statement => 'insert into replicate ( statement_key, svalues, sync_peer_1, sync_peer_2, sync_peer_3, sync_peer_4, sync_peer_5, sync_peer_6 ) values ( ?, ?, ?, ?, ?, ?, ?, ? )', values => [ $statement_key, $svalues, $sync_flag, $sync_flag, $sync_flag, $sync_flag, $sync_flag, $sync_flag ] );
    }

    return $nr_rows;
}


#-----------------------#
sub last_replication_id {
#-----------------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $peer_nr   = $args{peer_nr};

    my $query = 'select max(id) from replicate'; 
    if ( $peer_nr ) {
        $query .= " where sync_peer_${peer_nr} = 'Y'";
    }
    else {
        $query .= " where sync_peer_1 = 'Y' and sync_peer_2 = 'Y' and sync_peer_3 = 'Y' and sync_peer_4 = 'Y' and sync_peer_5 = 'Y' and sync_peer_6 = 'Y'";
    }

    my $result = $self->{oracle}->query( query => $query, quiet => 1 );

    my ( $id ) = $result->next;

    $id ||= 0;

    return $id;
}


#----------------------#
sub max_replication_id {
#----------------------#
    my ( $self, %args ) = @_;


    my $query = 'select max(id) from replicate'; 

    my $result = $self->{oracle}->query( query => $query, quiet => 1 );

    my ( $id ) = $result->next;

    $id ||= 0;

    return $id;
}

#-------------------#
sub set_sync_status {
#-------------------#
    my ( $self, %args ) = @_;


    my $id      = $args{id};
    my $peer_nr = $args{peer_nr};

    my $statement = "update replicate set sync_peer_${peer_nr} = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ 'Y', $id ] );
}

#---------------------------#
sub statements_to_replicate { 
#---------------------------#
    my ( $self, %args ) = @_;


    my $peer_nr = $args{peer_nr};

    my $query = "select id, statement_key, svalues from replicate where sync_peer_${peer_nr} = ? order by id";

    $self->{oracle}->query( query => $query, values => [ 'N' ] );
}

#-----------#
sub next_id {
#-----------#
    my ( $self, %args ) = @_;


    my $table = $args{table}; 
    unless ( $table ) {
        $self->{logger}->logdie("missing argument in next_id (table)");
    }

    my $start_id = $START_ID{$table};

    my $query = "select max(id) from $table";

    my $result = $self->{oracle}->query( query => $query );

    my ( $id ) = $result->next;

    $id++;

    $id = $start_id if $id < $start_id;

    return $id;
}

#-----------------#
sub export_tables {
#-----------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $sybase    = $self->{sybase};
    my $directory = $args{directory};

    unless ( $directory ) {
        $logger->logdie("missing argument in export (directory)");
    }

    $logger->info("starting export of the authorization database");
    $logger->info("export directory is $directory");

    foreach my $table ( @TABLES ) {
        my $file = $directory . '/' . $table . '.out';

        my $owner = $sybase->table_owner( $table );

        unless ( $sybase->bcp_out( table => "$owner.$table", file => $file, delimiter => '%' ) ) {
            $logger->logdie("aborting export");
        }
    }

    return 1;
}

#-----------------#
sub import_tables {
#-----------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $sybase    = $self->{sybase};
    my $directory = $args{directory};

    unless ( $directory ) {
        $logger->logdie("missing argument in import (directory)");
    }

    $logger->info("starting import of the authorization database");
    $logger->info("import directory is $directory");

    foreach my $table ( @TABLES ) {
        my $file = $directory . '/' . $table . '.out';

        unless ( -f $file ) {
            $logger->logdie("cannot find file for import ($file)");
        }

        $sybase->do( statement => "truncate table $table" );

        $logger->info("table $table truncated");

        my $owner = $sybase->table_owner( $table );

        unless ( $sybase->bcp_in( table => "$owner.$table", file => $file, delimiter => '%' ) ) {
            $logger->logdie("aborting import");
        }
    }

    return 1;
}

#------------------#
sub retrieve_users {
#------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_users';
    return $self->_retrieve( %args );
}

#-------------------#
sub retrieve_groups {
#-------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_groups';
    return $self->_retrieve( %args );
}

#-------------------------#
sub retrieve_environments {
#-------------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_environments';
    return $self->_retrieve( %args );
}

#-------------------#
sub retrieve_rights {
#-------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_rights';
    return $self->_retrieve( %args );
}

#---------#
sub close {
#---------#
    my ( $self ) = @_;


    $self->{oracle}->close;
    $self->{oracle} = undef;

    return 1;
}

#
# Arguments
#
# where          hashref containing the select criteria
# sort           hashref containing the sort criteria ( a true value for ascending, a false for descending)
# page_nr        which 'page' of results
# recs_per_page  nr of results per page
#
#-------------#
sub _retrieve {
#-------------#
    my ( $self, %args ) = @_;


    my $where_clause = '';
    if ( $args{where} && ref($args{where}) eq 'HASH' ) {
        my @and_components = ();
        my %where = %{$args{where}};
        while ( my ($key, $value) = each %where ) {
            if ( ref($value) eq 'ARRAY' ) {
                my @list = ();
                foreach my $entry ( @{$value} ) {
                    if ( $key =~ /^\*(.+)$/ ) {
                        push @list, "$1 like \"%$value%\"";
                    } 
                    else {
                        push @list, "$key = $value";
                    }
                }  
                push @and_components, ( join ' or ', @list );
            }
            else {
                if ( $key =~ /^\*(.+)$/ ) {
                    push @and_components, "$1 like \"%$value%\"";
                } 
                else {
                    push @and_components, "$key = $value";
                }
            }
        }
        $where_clause = join ' and ', @and_components;
    }

    my $sort_clause = 'id';
    if ( $args{sort} && ref($args{sort}) eq 'HASH' ) {
        my @sort_components = ();
        my %sort = %{$args{sort}};
        while ( my ($key, $value) = each %sort ) {
            push @sort_components, $key . ( $value ? ' asc' : ' desc' );
        }
        $sort_clause = join ',', @sort_components;
    }

    my $page_nr          = $args{page_nr} || 1;
    my $recs_per_page    = $args{recs_per_page} || 30;
    my $stored_procedure = $args{stored_procedure};

    my $statement = "begin $stored_procedure($page_nr, $recs_per_page, '$sort_clause'," . ( $where_clause ? ",'$where_clause'":"''" ) . ", ?:C); end;";

    my $cursor;
    my $result = $self->{oracle}->do( statement => $statement, nocache => 1, cr_values => [ \$cursor ] );

    my $rows = $cursor->fetchall_arrayref();

    return @{$rows};
}

1;
