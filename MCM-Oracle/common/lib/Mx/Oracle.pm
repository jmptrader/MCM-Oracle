package Mx::Oracle;

use strict;
use warnings;

use Mx::Database::ResultSet;
use Mx::Database::Index;
use String::CRC::Cksum qw( cksum );
use Carp;
use DBI qw( :sql_types );
use DBD::Oracle qw( :ora_types );
use Time::HiRes qw( time );

use constant OPEN   => 1;
use constant CLOSED => 2;

#
# Method used to initialize a connection with the Oracle server, not to actually open it.
# Arguments:
# database:      name of the database (optional)
# username:      user used to connect to the server
# password:      her password
# logger:        the usual Mx::Log object
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument in initialisation of database connection (config)'); 
    }
    $self->{config} = $config; 

    #
    # check the arguments
    #
    my @required_args = qw(database username password);
    foreach my $arg (@required_args) {
        unless ( $self->{$arg} = $args{$arg} ) {
            $logger->logdie("missing argument in initialisation of database connection ($arg)");
        }
    }

    $self->{status} = CLOSED;

    $logger->debug('database connection to ', $self->{database}, ' as user ', $self->{username}, ' initialized');

    $self->{nocache}          = $args{nocache};
    $self->{cached_query}     = {};
    $self->{cached_statement} = {};

    bless $self, $class;
}

#---------#
sub clone {
#---------#
    my ( $self ) = @_;


    my $object = {};

    $object->{logger}           = $self->{logger};
    $object->{config}           = $self->{config};
    $object->{database}         = $self->{database};
    $object->{username}         = $self->{username};
    $object->{password}         = $self->{password};
    $object->{status}           = $self->{status};
    $object->{nocache}          = $self->{nocache};
    $object->{cached_query}     = $self->{cached_query};
    $object->{cached_statement} = $self->{cached_statement};
    $object->{dbh}              = $self->{dbh};

    bless $object, ref( $self );
}

#-------------#
sub duplicate {
#-------------#
    my ( $self ) = @_;


    my $object = {};

    $object->{logger}           = $self->{logger};
    $object->{config}           = $self->{config};
    $object->{database}         = $self->{database};
    $object->{username}         = $self->{username};
    $object->{password}         = $self->{password};
    $object->{status}           = CLOSED;
    $object->{nocache}          = $self->{nocache};
    $object->{cached_query}     = {};
    $object->{cached_statement} = {};
    $object->{dbh}              = undef;

    bless $object, ref( $self );
}

#--------#
sub open {
#--------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    unless ( $self->{status} == CLOSED ) {
        $logger->warn('trying to open a database connection to', $self->{database}, ' which is not closed');
        return 1;
    }

    $logger->debug('trying to connect to database ', $self->{database}, ' as user ', $self->{username});

    my $connectstring = 'dbi:Oracle:' . $self->{database};

    my $attributes = ( $args{private} ) ? { x => time() } : { ora_verbose => 0 };

    eval {
        unless ( $self->{dbh} = DBI->connect( $connectstring, $self->{username}, $self->{password}, $attributes ) ) {
            $logger->warn('unable to connect to database ', $self->{database}, ' as user ', $self->{username}, ': ', $DBI::errstr);
            return;
        };
    };

    if ( $@ ) {
        $logger->logdie("cannot connect to database $self->{database}: $@");
    }

    $self->{dbh}->{LongReadLen} = 2 * 1024 * 1024;

    $logger->debug( 'connected to database ', $self->{database}, ' as user ', $self->{username} );

    #
    # Try to get the database session id. This is a good check for the database handle, and the sid can be stored for later use.
    #
    my $arrayref;
    unless ( $arrayref = $self->{dbh}->selectrow_arrayref('SELECT sid FROM v$mystat WHERE rownum = 1') ) {
        $self->{logger}->warn( 'cannot select sid: ', $self->{dbh}->errstr );
        return;
    }

    my $sid;
    unless ( $sid = $arrayref->[0] ) {
        $logger->warn('sid is empty');
        return;
    }
    else {
        $self->{sid} = $sid;
        $logger->debug("sid is $sid");
    }

    $self->{ChopBlanks} = 0;
    $self->{status}     = OPEN;

    return 1;
}

#-------------#
sub logintime {
#-------------#
    my ( $self ) = @_;


    my $connectstring = 'dbi:Oracle:' . $self->{database};

    my $start_time = time();

    my $dbh;
    unless ( $dbh = DBI->connect( $connectstring, $self->{username}, $self->{password}, { x => $start_time } ) ) {
        $self->{logger}->warn('unable to connect to database ', $self->{database}, ' as user ', $self->{username}, ': ', $DBI::errstr);
        return -1;
    }

    my $interval = time() - $start_time;

    $dbh->disconnect;

    return $interval;
}

#----------#
sub commit {
#----------#
    my ( $self ) = @_;

    $self->{dbh}->commit;
}

#
#
# statement
# values[]
# io_values[]
# nocache: boolean
#
#------#
sub do {
#------#
    my ( $self, %args ) = @_;


    my $statement;
    unless ( $statement = $args{statement} ) {
        $self->{logger}->error('no statement specified');
        return;
    }

    my @bind_params = (); my @bind_io_params = (); my @bind_cr_params = (); my @bind_bl_params = ();
    if ( my @placeholders = $statement =~ /(\?(?::[OCB])?)/g ) {
        for ( my $i = 0; $i < @placeholders; $i++ ) {
            push @bind_params,    $i + 1 if ( $placeholders[$i] eq '?' );
            push @bind_io_params, $i + 1 if ( $placeholders[$i] eq '?:O' );
            push @bind_cr_params, $i + 1 if ( $placeholders[$i] eq '?:C' );
            push @bind_bl_params, $i + 1 if ( $placeholders[$i] eq '?:B' );
        }
        if ( @bind_io_params or @bind_cr_params or @bind_bl_params ) {
            $statement =~ s/\?:[OCB]/?/g;
        }
    }

    my @bind_values = ();
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $self->{logger}->error('values must be specified via an array reference');
            return;
        }
        @bind_values = @{$args{values}};
    }

    my @bind_io_values = ();
    if ( $args{io_values} ) {
        unless ( ref( $args{io_values} ) eq 'ARRAY' ) {
            $self->{logger}->error('I/O values must be specified via an array reference');
            return;
        }
        @bind_io_values = @{$args{io_values}};
    }

    my @bind_cr_values = ();
    if ( $args{cr_values} ) {
        unless ( ref( $args{cr_values} ) eq 'ARRAY' ) {
            $self->{logger}->error('Cursor values must be specified via an array reference');
            return;
        }
        @bind_cr_values = @{$args{cr_values}};
    }

    my @bind_bl_values = ();
    if ( $args{bl_values} ) {
        unless ( ref( $args{bl_values} ) eq 'ARRAY' ) {
            $self->{logger}->error('BLOB values must be specified via an array reference');
            return;
        }
        @bind_bl_values = @{$args{bl_values}};
    }

	if ( @bind_io_params != @bind_io_values ) {
		$self->{logger}->error('number of I/O placeholders does not match number of I/O values');
		return;
    }

    #
    # prepare the statement
    #
    my $sth;
    if ( ! $args{nocache} && ! $self->{nocache} && exists $self->{cached_statement}->{$statement} ) {
        $sth = $self->{cached_statement}->{$statement};
    }
    else {
        unless ( $sth = $self->{dbh}->prepare( $statement ) ) {
            $self->{logger}->error('SQL prepare failed: ', $self->{dbh}->errstr);
            return;
        }

        $self->{cached_statement} = { $statement => $sth } unless $args{nocache} or $self->{nocache};
    }

    foreach ( @bind_params ) {
        $sth->bind_param( $_, shift( @bind_values ) );
    }

    foreach ( @bind_io_params ) {
        $sth->bind_param_inout( $_, shift( @bind_io_values ), 50 );
    }

    foreach ( @bind_cr_params ) {
        $sth->bind_param_inout( $_, shift( @bind_cr_values ), 0, { ora_type => ORA_RSET } );
    }

    foreach ( @bind_bl_params ) {
        $sth->bind_param( $_, shift( @bind_bl_values ), { ora_type => SQLT_BIN } );
    }

    my $nr_rows;
    unless ( $nr_rows = $sth->execute ) {
        my $errstr = $sth->errstr || '';
        $self->{logger}->error('SQL excute failed: ', $errstr);
        return;
    }

    $sth->finish if $args{nocache} or $self->{nocache};

    return $nr_rows;
}

#
# query
# values[]
# nocache: boolean
# quiet:   boolean
# delayed: boolean
#
#---------#
sub query {
#---------#
    my ( $self, %args ) = @_;



	$args{nocache} = 1;

    my $query;
    unless ( $query = $args{query} ) {
        $self->{logger}->error('no query specified');
        return;
    }

    my @bind_params = ();
    if ( my @placeholders = $query =~ /(\?(?::[I])?)/g ) {
        for ( my $i = 0; $i < @placeholders; $i++ ) {
            push @bind_params, $i + 1 if ( $placeholders[$i] eq '?:I' );
        }
        if ( @bind_params ) {
            $query =~ s/\?:[I]/?/g;
        }
    }

    my @bind_values = ();
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $self->{logger}->error('values must be specified via an array reference');
            return;
        }
        @bind_values = @{$args{values}};
    }

    unless( $args{quiet} ) {
        $self->{logger}->debug($query);
    }    

    #
    # prepare the query
    #
    my $sth;
    if ( ! $args{nocache} && ! $self->{nocache} && exists $self->{cached_query}->{$query} ) {
        $sth = $self->{cached_query}->{$query};
    }
    else {
        unless ( $sth = $self->{dbh}->prepare( $query ) ) {
            $self->{logger}->error('SQL prepare failed: ', $self->{dbh}->errstr);
            return;
        }

        foreach my $nr ( @bind_params ) {
			my ( $value ) = splice @bind_values, $nr -1, 1;
            $sth->bind_param( $nr, $value, ORA_NUMBER );
        }

        $self->{cached_query} = { $query => $sth } unless $args{nocache} or $self->{nocache};
    }

    #
    # execute the query
    #
    $self->{logger}->debug('executing SQL query') unless $args{quiet};

#    $self->{logger}->debug("bind values: @bind_values") if @bind_values;
    unless ( $sth->execute( @bind_values ) ) {
        $self->{logger}->error('SQL execute failed: ', $sth->errstr);
        return;
    }

    #
    # fetch the results
    #
    my $values_ref;
    unless ( $args{delayed} ) {
        unless ( $values_ref = $sth->fetchall_arrayref() ) {
            $self->{logger}->error('SQL fetch failed: ', $sth->errstr);
            return;
        }
    }

    my $columns_ref = $sth->{NAME_lc};

    if ( $args{delayed} ) {
        return Mx::Database::ResultSet->new( sth => $sth, columns => $columns_ref, logger => $self->{logger} );
    }
    else {
        return Mx::Database::ResultSet->new( values => $values_ref, columns => $columns_ref, logger => $self->{logger} );
    }
}

#
# Executes a query which contains embedded semicolons, for intermediary commits.
# The query is split up and each part is executed separately.
#
#-------------------#
sub composite_query {
#-------------------#
    my ( $self, %args ) = @_;
   
    my $query;
    unless ( $query = $args{query} ) {
        $self->{logger}->error('no query specified');
        return;
    }
    
    my @bind_values = ();
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $self->{logger}->error('values must be specified via an array reference');
            return;
        }
        @bind_values = @{$args{values}};
    }

    my @subqueries = split /;\n/, $query;

    my $result;
    while ( my $subquery = shift @subqueries ) {
        my $nr_placeholders = ( $subquery =~ tr/?// );

        unless ( $nr_placeholders <= scalar( @bind_values ) ) {
            $self->{logger}->error('not enough bind values specified');
            return;
        }

        my @sub_bind_values = splice( @bind_values, 0, $nr_placeholders );

        if ( @subqueries ) {
            return unless $self->do( statement => $subquery, values => \@sub_bind_values );
        }
        else {
            $result = $self->query( query => $subquery, values => \@sub_bind_values, quiet => $args{quiet} );
        }
    }

    return $result;
}

#
# Executes a statement which contains embedded semicolons, for intermediary commits.
# The statement is split up and each part is executed separately.
#
#----------------#
sub composite_do {
#----------------#
    my ( $self, %args ) = @_;
 
 
    my $statement;
    unless ( $statement = $args{statement} ) {
        $self->{logger}->error('no statement specified');
        return;
    }
 
    my @bind_values = ();
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $self->{logger}->error('values must be specified via an array reference');
            return;
        }

        @bind_values = @{$args{values}};
    }
 
    my @substatements = split /;\n/, $statement;
 
    my $nr_rows;
    while ( my $substatement = shift @substatements ) {
        my $nr_placeholders = ( $substatement =~ tr/?// );

        unless ( $nr_placeholders <= scalar( @bind_values ) ) {
            $self->{logger}->error('not enough bind values specified');
            return;
        }

        my @sub_bind_values = splice( @bind_values, 0, $nr_placeholders );

        return unless $nr_rows = $self->do( statement => $substatement, values => \@sub_bind_values );
    }
 
    return $nr_rows;
}

#
# does multiple inserts or updates
# 
#---------------#
sub do_multiple {
#---------------#
    my ( $self, %args ) = @_;

    
    my $sql;
    unless ( $sql = $args{sql} ) {
        $self->{logger}->error('no sql specified');
        return;
    }

    unless( $args{quiet} ){
        $self->{logger}->debug( $sql );
    }

    my @bind_params = ();
    if ( my @placeholders = $sql =~ /(\?(?::F)?)/g ) {
        for ( my $i = 0; $i < @placeholders; $i++ ) {
            push @bind_params, $i + 1 if ( $placeholders[$i] eq '?:F' );
        }
        if ( @bind_params ) {
            $sql =~ s/\?:F/?/g;
        }
    }
    
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $self->{logger}->error('values must be specified via an array reference');
            return;
        }
    }

    $self->{logger}->debug( "bind values: ".( scalar @{ $args{values} } )." sets" );

    # prepare the sql
    #
    my $sth;
    unless ( $sth = $self->{dbh}->prepare($sql) ) {
        $self->{logger}->error('SQL prepare failed: ', $self->{dbh}->errstr);
        return;
    }

    foreach ( @bind_params ) {
        $sth->bind_param( $_, 0.0, SQL_FLOAT );
    }

    #
    # execute the sql
    #
    $self->{logger}->debug('executing SQL');

    foreach my $row( @{ $args{values} } ){
        unless ( $sth->execute( @{$row} ) ) {
            my @values = @{$row};
            $self->{logger}->error( "SQL execute failed with bind values @values: ", $sth->errstr );
            return;
        }
    }

    return 1;
}

#
# kills all connections to a particular schema
#
#------------#
sub kill_all {
#------------#
    my ( $self ) = @_;


	my $schema = $self->{username};

    $self->{logger}->debug("trying to kill all connections to schema $schema");

    #
    # check which sessions are connected to this particular schema
    #
    my $result;
    unless ( $result = $self->query( query => 'SELECT sid, serial# FROM v$session WHERE schemaname = ? AND sid <> ?', values => [ $schema, $self->{sid} ] ) ) {
        $self->{logger}->error("cannot get list of connections to schema $schema");
        return;
    }

	my @connections = $result->all_rows();

    if ( my $nr_connections = @connections ) {
        $self->{logger}->debug("numbers of connections to schema $schema: $nr_connections");
    }
    else {
        $self->{logger}->debug("no connections to schema $schema found");
        return 1;
    }

	my $rc = 1;
	foreach my $connection ( @connections ) {
	    my $sid    = $connection->[0];
	    my $serial = $connection->[1];
        my $statement = "ALTER SYSTEM KILL SESSION '$sid,$serial' IMMEDIATE";

        if ( $self->do( statement => $statement ) ) {
            $self->{logger}->debug("connection to schema $schema with sid $sid killed");
        }
        else {
            $rc = 0; 
            $self->{logger}->error("cannot kill the connection to schema $schema with sid $sid");
        }
    }

	return $rc;
}

#--------#
sub kill {
#--------#
    my ( $self, %args ) = @_;


	my $sid    = $args{sid};
	my $serial = $args{serial};

    $self->{logger}->debug("trying to kill connection with sid $sid and serial $serial");

    #
    # build the kill statement...
    #
    my $statement = "ALTER SYSTEM KILL SESSION '$sid,$serial' IMMEDIATE";

    if ( $self->do( statement => $statement ) ) {
        $self->{logger}->debug("connection with sid $sid and serial $serial killed");
		return 1; 
    }
    else {
        $self->{logger}->error("cannot kill the connection with sid $sid and serial $serial");
		return 0; 
    }
}

#---------------#
sub connections {
#---------------#
    my ( $self, %args ) = @_;


    #
    # if no schema is given as argument, take the one stored in the object
    #
    my $schema = $args{schema} || $self->{username};

    my $query = "SELECT 
	  s1.schemaname,
	  s1.sid,
	  s1.serial#,
      s1.username,
	  s1.osuser,
	  s1.machine,
	  s1.process,
	  s1.program,
	  to_char(s1.logon_time, 'YYYY-MM-DD HH24:MI:SS'),
	  s1.status,
	  s1.last_call_et,
      c1.command_name,
	  ( select value from v\$sesstat p1 where p1.sid = s1.sid and p1.statistic# = 16 ) as cpu,
	  ( select value from v\$sesstat p1 where p1.sid = s1.sid and p1.statistic# = 11 ) as lreads,
	  ( select value from v\$sesstat p1 where p1.sid = s1.sid and p1.statistic# = 75 ) as preads,
	  ( select value from v\$sesstat p1 where p1.sid = s1.sid and p1.statistic# = 86 ) as pwrites,
	  s1.blocking_session,
	  s1.wait_time,
	  s1.seconds_in_wait
	  FROM v\$session s1
	  INNER JOIN v\$sqlcommand c1 ON ( s1.command = c1.command_type )
	  WHERE s1.schemaname = ?";

    my @values = ( $schema );

    #
    # check which spid's are connected to this particular database
    #
    my $result;
    unless ( $result = $self->query( query => $query, values => \@values, quiet => 1 ) ) {
        $self->{logger}->error("cannot get list of connections to schema $schema");
        return;
    };

    return $result->all_rows();
}


#------------#
sub sql_text {
#------------#
    my ( $self, %args ) = @_;


	my $sid    = $args{sid};
	my $serial = $args{serial};

	my $prev_sql_text; my @prev_bind_values; my $sql_text; my @bind_values;

	if ( $args{previous} ) {
	    my $query = 'select a.sql_fulltext, b.name, b.value_string
	      from v$session s
          join v$sql a on              ( a.hash_value = s.prev_hash_value and a.address = s.prev_sql_addr and a.child_number = s.prev_child_number )
          join v$sql_bind_capture b on ( b.hash_value = s.prev_hash_value and b.address = s.prev_sql_addr and b.child_number = s.prev_child_number )
	      where s.sid = ?
	      and s.serial# = ?
        ';

	    my $result = $self->query( query => $query, values => [ $sid, $serial ], quiet => 1 );

        while ( my $row = $result->nextref ) {
			last unless @{$row}; 
            $prev_sql_text = $row->[0] unless $prev_sql_text;
            push @prev_bind_values, { $row->[1] => $row->[2] };
        }
    }

	my $query = 'select a.sql_fulltext, b.name, b.value_string
	  from v$session s
      join v$sql a on              ( a.hash_value = s.sql_hash_value and a.address = s.sql_address and a.child_number = s.sql_child_number )
      join v$sql_bind_capture b on ( b.hash_value = s.sql_hash_value and b.address = s.sql_address and b.child_number = s.sql_child_number )
	  where s.sid = ?
	  and s.serial# = ?
    ';

	my $result = $self->query( query => $query, values => [ $sid, $serial ], quiet => 1 );

    while ( my $row = $result->nextref ) {
        last unless @{$row}; 
        $sql_text = $row->[0] unless $sql_text;
        push @bind_values, { $row->[1] => $row->[2] };
    }

	return ( $sql_text, \@bind_values, $prev_sql_text, \@prev_bind_values );
}

#------------#
sub sql_plan {
#------------#
    my ( $self, %args ) = @_;


	my $sid    = $args{sid};
	my $serial = $args{serial};

	$self->do( statement => 'delete from plan_table' ); 

	my $statement = "insert into plan_table select
	  'my_query',
	  p.child_number,
	  sysdate,
      '',
	  p.operation,
	  p.options,
	  p.object_node,
	  p.object_owner,
	  p.object_name,
	  p.object_alias,
	  0,
	  p.object_type,
	  p.optimizer,
	  p.search_columns,
	  p.id,
	  p.parent_id,
	  p.depth,
	  p.position,
	  p.cost,
	  p.cardinality,
	  p.bytes,
	  p.other_tag,
	  p.partition_start,
	  p.partition_stop,
	  p.partition_id,
	  p.other,
	  p.other_xml,
	  p.distribution,
	  p.cpu_cost,
	  p.io_cost,
	  p.temp_space,
	  p.access_predicates,
	  p.filter_predicates,
	  p.projection,
	  p.time,
	  p.qblock_name
    from v\$sql_plan p join v\$session s on (
	  s.sql_address = p.address and
	  s.sql_hash_value = p.hash_value and
	  s.sql_child_number = p.child_number
	  )
    where s.sid = ? and s.serial# = ?";

	$self->do( statement => $statement, values => [ $sid, $serial ] );

	my $query = "select * from table(dbms_xplan.display('plan_table', 'my_query', 'ALL'))"; 

	my $result = $self->query( query => $query, quiet => 1 );

	return map { $_->[0] } $result->all_rows;
}

#---------#
sub locks {
#---------#
    my ( $self, %args ) = @_;
    

    #
    # if no schema is given as argument, take the one stored in the object
    #
    my $schema = $args{schema} || $self->{username};

    my $result;
    unless ( $result = $self->query( query => "SELECT
	  s1.schemaname,
	  s1.sid,
	  s1.serial#,
	  s1.username,
	  s1.machine,
	  s1.process,
	  s1.program,
	  l1.type,
	  o1.object_name,
	  decode( l1.lmode,
		1,'No Lock',
		2,'Row Share',
		3,'Row Exclusive',
		4,'Share',
		5,'Share Row Exclusive',
		6,'Exclusive',
		'NONE') lmode,
	  l1.ctime
	  FROM v\$lock l1
	  INNER JOIN v\$session s1 ON s1.sid = l1.sid
	  INNER JOIN dba_objects o1 ON o1.object_id = l1.id1
	  WHERE s1.schemaname = ?
	  AND l1.type IN ('TM', 'TX', 'UL')", values => [ $schema ], quiet => 1 ) ) {
        $self->{logger}->error("cannot get list of locks in schema $schema");
        return;
    };

	return $result->all_rows();
}

#---------------------#
sub table_column_info {
#---------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $table;
    unless ( $table = uc $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};

    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }

    my $sth;
    unless ( $sth = $self->{dbh}->column_info( $schema, '%', $table, '%' ) ) {
        $logger->error("cannot retrieve column info for table $table ($schema): " . $self->{dbh}->errstr);
        return;
    }

    my @columns = ();
    while ( my $column_ref = $sth->fetchrow_arrayref ) {
        my $column = {};
        $column->{name}      = $column_ref->[3];
        $column->{type}      = $column_ref->[5];
        $column->{length}    = $column_ref->[6];
        $column->{precision} = $column_ref->[8];
        $column->{nullable}  = $column_ref->[10];
        push @columns, $column;
    }

    return @columns;
}

#-------------#
sub table_ddl {
#-------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $table;
    unless ( $table = uc $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};

    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }

    my @columns    = $self->table_column_info( table => $table, schema => $schema );
    my $nr_columns = @columns;

    my $ddl = "create table $table (\n";

    my $count = 0;
    foreach my $column ( @columns ) {
        $count++;

        $ddl .= $column->{name} . ' ';

        if ( $column->{type} eq 'NUMBER' ) {
			if ( $column->{precision} == 0 ) {
                $ddl .= $column->{type} . '(' . $column->{length} . ')';
            }
			else { 
                $ddl .= $column->{type} . '(' . $column->{length} . ',' . $column->{precision} . ')';
            }
        }
        elsif ( $column->{type} eq 'FLOAT' ) {
            $ddl .= $column->{type} . '(' . $column->{length} . ')';
        }
        elsif ( $column->{type} eq 'CHAR' or $column->{type} eq 'VARCHAR2' ) {
            $ddl .= $column->{type} . '(' . $column->{length} . ')';
        }
        else {
            $ddl .= $column->{type};
        }

        $ddl .= ( $column->{nullable} ) ? ' null' : ' not null';

        $ddl .= ( $count == $nr_columns ) ? "\n)\n" : ",\n";
    }

    return $ddl;
}

#--------------------#
sub table_index_info {
#--------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};

    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }

    my ( $indexes_ref ) = Mx::Database::Index->retrieve_existing_indexes( tables => [ $table ], schema => $schema, oracle => $self->clone, config => $config, logger => $logger );

    return values %{$indexes_ref};
}

#-------------------#
sub table_size_info {
#-------------------#
    my ( $self, %args ) = @_;
 
 
    my $config = $self->{config};
    my $logger = $self->{logger};

    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};
 
    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }
 
    my $result;
	unless ( $args{no_existence_check} ) {
        unless ( $result = $self->query( query => "SELECT num_rows FROM user_tables WHERE table_name = ?", values => [ $table ], quiet => 1 ) ) {
            $logger->error("cannot determine table existence");
            return;
        }
 
        unless ( $result->next() ) {
            return;
        }
    }
 
    unless ( $result = $self->query( query => "select count(*) from $table", quiet => 1 ) ) {
        $logger->error("cannot determine table size");
        return;
    }

    if ( my @row = $result->next() ) {
        return $row[0];
    }
}

#--------------------#
sub table_space_info {
#--------------------#
    my ( $self, %args ) = @_;
 
 
    my $config = $self->{config};
    my $logger = $self->{logger};
 
    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};
 
    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }
 
    my $result;
    unless ( $result = $self->query( query => "SELECT
      ( SELECT NVL(TRUNC(SUM(s.bytes)/1024),0) FROM dba_segments s WHERE s.segment_name = ? AND s.owner = ? AND s.segment_type = 'TABLE' ) AS tablesize,
      ( SELECT NVL(TRUNC(SUM(s.bytes)/1024),0) FROM dba_segments s, dba_indexes i WHERE s.segment_name = i.index_name AND i.table_name = ? AND i.owner = ? AND s.owner = ? AND s.segment_type = 'INDEX' ) AS indexsize,
      ( SELECT NVL(TRUNC(SUM(s.bytes)/1024),0) FROM dba_segments s, dba_lobs l WHERE s.segment_name = l.segment_name AND l.table_name = ? AND l.owner = ? AND s.owner = ? AND s.segment_type = 'LOBSEGMENT' ) AS lobsize,
      ( SELECT NVL(TRUNC(SUM(s.bytes)/1024),0) FROM dba_segments s, dba_lobs l WHERE s.segment_name = l.index_name AND l.table_name = ? AND l.owner = ? AND s.owner = ? AND s.segment_type = 'LOBINDEX' ) AS lobindexsize
	  FROM DUAL", values => [ $table, $schema, $table, $schema, $schema, $table, $schema, $schema, $table, $schema, $schema ], quiet => 1 ) ) {
        $logger->error("cannot determine size of table $table in schema $schema");
        return;
    }

	my ( $tablesize, $indexsize, $lobsize, $lobindexsize ) = $result->next();

	return ( data => $tablesize, indexes => $indexsize, lobs => $lobsize, lobindexes => $lobindexsize, total_size => $tablesize + $indexsize + $lobsize + $lobindexsize );
}

#---------------#
sub table_owner {
#---------------#
    my ( $self, %args ) = @_;
 
 
    my $config = $self->{config};
    my $logger = $self->{logger};
 
    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }
 
    my $result;
    unless ( $result = $self->query( query => "select owner from all_tables where table_name = ?", values => [ $table ], quiet => 1 ) ) {
        $logger->error("cannot determine owner of table $table");
        return;
    }
 
    my ( $owner ) = $result->next();

    return $owner;
}

#-----------------#
sub table_extract {
#-----------------#
    my ( $self, %args ) = @_;


    my $config = $self->{config};
    my $logger = $self->{logger};
 
    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $schema = $args{schema} || $self->{username};
 
    if ( $table =~ /^([^.]+)\.([^.]+)$/ ) {
        $schema = $1;
        $table  = $2;
    }

    my $result = $self->query( query => "select top 10 * from $table" ); 

    return $result->all_rows();
}

#--------------#
sub all_tables {
#--------------#
    my ( $self, %args ) = @_;


    my $config = $self->{config};
    my $logger = $self->{logger};

    my $schema = $args{schema} || $self->{username};

    my @tables = $self->{dbh}->tables( $schema, $schema, '%', 'TABLE' );

	my @formatted_tables = ();
	foreach my $entry ( @tables ) {
      my ( $schema, $table ) = split '\.', $entry;
      $table =~ s/^"(.+)"$/$1/;
	  push @formatted_tables, $table
    }

    return @formatted_tables;
}

#-------------#
sub size_info {
#-------------#
    my ( $self, %args ) = @_;


    my $schema = $args{schema} || $self->{username};

	my $query = 'select
      A.default_tablespace as tablespace,
      ( select sum(bytes)/(1024*1024*1024) from dba_data_files where tablespace_name = A.default_tablespace ) as total,
      ( select sum(bytes)/(1024*1024*1024) from dba_segments   where tablespace_name = A.default_tablespace ) as used,
      ( select sum(bytes)/(1024*1024*1024) from dba_free_space where tablespace_name = A.default_tablespace ) as free
      from dba_users A
      where A.username = ?';

    my $result = $self->query( query => $query, values => [ $schema ], quiet => 1 );

	my $row = $result->nextref;

	my %info;
	$info{tablespace} = $row->[0];
	$info{total}      = sprintf "%.2f", $row->[1];
	$info{used}       = sprintf "%.2f", $row->[2];
	$info{free}       = sprintf "%.2f", $row->[3];

	return %info;
}

#-------------------#
sub connection_info {
#-------------------#
    my ( $self, %args ) = @_;


    my %info = ();

    my $result = $self->query( query => 'select schemaname, count(*) from v$session group by schemaname', quiet => 1 );

    my $total = 0;
    while ( my ($schema, $count) = $result->next ) {
        $info{$schema} = $count;
        $info{total}  += $count; 
    }

    return %info;
}
    
#-------#
sub sid {
#-------#
    my ( $self ) = @_;


    return $self->{sid};
}

#--------#
sub spid {
#--------#
    my ( $self ) = @_;


    return $self->{sid};
}

#----------#
sub schema {
#----------#
    my ( $self ) = @_;


    return $self->{username};
}

#-----------#
sub version {
#-----------#
    my ( $self ) = @_;


    my $result;
    unless ( $result = $self->query( query => 'select version from v$instance' ) ) {
        $self->{logger}->error("cannot determine database version");
        return;
    }
 
    my ( $version ) = $result->next();

    return $version;
}

#-----------#
sub sql_tag {
#-----------#
    my ( $class, $sql_text ) = @_;


    #
    # remove procedure names
    #
    $sql_text =~ s/ dyn\d+//g;

    #
    # remove temporary tables
    #
    $sql_text =~ s/tempdb\.\.\w+//g;

    #
    # remove newlines and whitespace
    #
    $sql_text =~ s/\s//g;

    #
    # remove string values
    #
    $sql_text =~ s/'.*?'//g;

    #
    # remove numbers in lists
    #
    $sql_text =~ s/\([\d,]+\)//g;

    #
    # remove remaining comma's in lists
    #
    $sql_text =~ s/\(,+\)//g;

    #
    # remove numeric comparisons
    #
    $sql_text =~ s/([<>=]+)\d+\.*\d*/$1/g;

    return cksum( $sql_text );
}

#---------#
sub close {
#---------#
    my ( $self ) = @_;


    $self->{cached_query}     = {};
    $self->{cached_statement} = {};
    $self->{dbh}->disconnect;
    $self->{status} = CLOSED;
    $self->{logger}->debug( 'database connection to ', $self->{database}, ' as user ', $self->{username}, ' closed' );
    return 1;
}

#-----------#
sub is_open {
#-----------#
    my ( $self ) = @_;


    return ( $self->{status} == OPEN );
}

#----------#
sub _rtrim {
#----------#
    my ( $string ) = @_;


    return unless $string;
    $string =~ s/\s+$//;
    return $string;
}

1;
