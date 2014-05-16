package Mx::Sybase;

use strict;

use Carp;
use DBI qw( :sql_types );
use IO::File;
use Text::CSV_XS;
use String::CRC::Cksum qw( cksum );
use Mx::Sybase::Index2;
use Mx::Sybase2;
use Time::HiRes qw( time );

use constant OPEN   => 1;
use constant CLOSED => 2;

use constant CSV_SEPARATOR => ',';
use constant CSV_EOL       => "
\n";


our @ERROR_HANDLER_MESSAGES = ();


#
# Method used to initialize a connection with the Sybase server, not to actually open it.
# Arguments:
# dsquery:       name of the Sybase server 
# database:      name of the database (optional)
# username:      user used to connect to the server
# password:      her password
# error_handler: boolean indicating if the error_handler needs to be installed (optional)
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
        $logger->logdie('missing argument in initialisation of Sybase (config)');
    }
    $self->{config} = $config;

    #
    # check the arguments
    #
    my @required_args = qw(dsquery username password);
    foreach my $arg (@required_args) {
        unless ( $self->{$arg} = $args{$arg} ) {
            $logger->logdie("missing argument in initialisation of Sybase connection ($arg)");
        }
    }
    #
    # check the optional 'database' argument
    #
    $self->{database} = $args{database} if $args{database}; 
    $self->{error_handler} = $args{error_handler};
    $self->{status} = CLOSED;
    if ( $self->{database} ) {
        $logger->debug('Sybase connection to ', $self->{dsquery}, ' as user ', $self->{username}, ' initialized (database: ', $self->{database}, ')');
    }
    else {
        $logger->debug('Sybase connection to ', $self->{dsquery}, ' as user ', $self->{username}, ' initialized');
    }

    $self->{nocache}          = $args{nocache};
    $self->{cached_query}     = {};
    $self->{cached_statement} = {};

    bless $self, $class;
}

#--------#
sub open {
#--------#
    my ($self, %args) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    unless ( $self->{status} == CLOSED ) {
        $logger->warn('trying to open a Sybase connection to ', $self->{dsquery}, ' which is not closed');
        return 1;
    }

    $logger->debug('trying to connect to the Sybase server on ', $self->{dsquery}, ' as user ', $self->{username}); 

    my $packetsize = $config->retrieve('SYB_PACKETSIZE');

    my $connectstring = 'dbi:Sybase:encryptPassword=1;charset=iso_1;server=' . $self->{dsquery} . ';packetSize=' . $packetsize . ';loginTimeout=180';
    $connectstring .= ';database=' . $self->{database} if $self->{database};

    my $attributes = ( $args{private} ) ? { x => time() } : {};

    eval {
        unless ( $self->{dbh} = DBI->connect( $connectstring, $self->{username}, $self->{password}, $attributes ) ) {
            $logger->warn('unable to connect to the Sybase server on ', $self->{dsquery}, ' as user ', $self->{username}, ': ', $DBI::errstr);
            return;
        };
    };

    if ( $@ ) {
        $logger->logdie("cannot connect to database $self->{dsquery}: $@");
    }

    if ( $self->{error_handler} == 1 ) {
        $self->{dbh}->{syb_err_handler} = \&_error_handler;
    }
    elsif ( $self->{error_handler} == 2 ) {
        $self->{dbh}->{syb_err_handler} = \&_error_handler_2;
    }

    $logger->debug( 'connected to the Sybase server on ', $self->{dsquery}, ' as user ', $self->{username} );

    #
    # Try to switch to the correct database (if specified)
    #
    if ( $self->{database} ) {
        if ( $self->{dbh}->do('use ' . $self->{database}) ) {
            $logger->debug('switched to database ', $self->{database});
        }
        else {
            $logger->warn('unable to switch to ', $self->{database});
            return;
        }
    }

    #
    # Try to get the Sybase spid. This is a good check for the database handle, and the spid can be stored for later use.
    #
    my $arrayref;
    unless ( $arrayref = $self->{dbh}->selectrow_arrayref('select @@spid') ) {
        $logger->warn( 'cannot select spid: ', $self->{dbh}->errstr );
        return;
    }

    my $spid;
    unless ( $spid = $arrayref->[0] ) {
        $logger->warn('spid is empty');
        return;
    }
    else {
        $self->{spid} = $spid;
        $logger->debug("spid is $spid");
    }

    $self->{status} = OPEN;

    return 1;
}

#-------------#
sub logintime {
#-------------#
    my ( $self ) = @_;


    my $connectstring = 'dbi:Sybase:encryptPassword=1;charset=iso_1;server=' . $self->{dsquery} . ';loginTimeout=180';
    $connectstring .= ';database=' . $self->{database} if $self->{database};

    my $start_time = time();

    my $dbh;
    unless ( $dbh = DBI->connect( $connectstring, $self->{username}, $self->{password}, { x => $start_time } ) ) {
        $self->{logger}->warn('unable to connect to the Sybase server on ', $self->{dsquery}, ' as user ', $self->{username}, ': ', $DBI::errstr);
        return -1;
    }

    my $interval = time() - $start_time;

    $dbh->disconnect;

    return $interval;
}

#---------#
sub clone {
#---------#
    my ( $self ) = @_;


    my $object = {};

    $object->{logger}           = $self->{logger};
    $object->{config}           = $self->{config};
    $object->{dsquery}          = $self->{dsquery};
    $object->{username}         = $self->{username};
    $object->{password}         = $self->{password};
    $object->{database}         = $self->{database};
    $object->{error_handler}    = $self->{error_handler};
    $object->{status}           = $self->{status};
    $object->{nocache}          = $self->{nocache};
    $object->{cached_query}     = $self->{cached_query};
    $object->{cached_statement} = $self->{cached_statement};
    $object->{dbh}              = $self->{dbh};

    bless $object, 'Mx::Sybase2';
}

#-------------#
sub duplicate {
#-------------#
    my ( $self ) = @_;


    my $object = {};

    $object->{logger}           = $self->{logger};
    $object->{config}           = $self->{config};
    $object->{dsquery}          = $self->{dsquery};
    $object->{username}         = $self->{username};
    $object->{password}         = $self->{password};
    $object->{database}         = $self->{database};
    $object->{error_handler}    = $self->{error_handler};
    $object->{status}           = CLOSED;
    $object->{nocache}          = $self->{nocache};
    $object->{cached_query}     = {};
    $object->{cached_statement} = {};
    $object->{dbh}              = undef;

    bless $object, 'Mx::Sybase';
}

#
# switch to the specified database
#
#-------#
sub use {
#-------#
    my ($self, $database) = @_;
    

    unless ( $database ) {
        $self->{logger}->logdie("missing argument (database)");
    }
    if ( $self->{dbh}->do("use $database") ) {
        $self->{logger}->debug("switched to database $database");
        $self->{database}         = $database;
        $self->{cached_query}     = {};
        $self->{cached_statement} = {};
        return 1;
    }
    else {
        $self->{logger}->warn("unable to switch to $database");
        return;
    }
}
 

#------#
sub do {
#------#
    my ($self, %args) = @_;


    my $statement;
    unless ( $statement = $args{statement} ) {
        $self->{logger}->error('no statement specified');
        return;
    }

    my @bind_params = ();
    if ( my @placeholders = $statement =~ /(\?(?::F)?)/g ) {
        for ( my $i = 0; $i < @placeholders; $i++ ) {
            push @bind_params, $i + 1 if ( $placeholders[$i] eq '?:F' );
        }
        if ( @bind_params ) {
            $statement =~ s/\?:F/?/g;
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

    #
    # prepare the statement
    #
    my $sth;
    if ( ! $args{nocache} && ! $self->{nocache} && exists $self->{cached_statement}->{$statement} ) {
        $sth = $self->{cached_statement}->{$statement};
    }
    else {
        unless ( $sth = $self->{dbh}->prepare($statement) ) {
            $self->{logger}->error('SQL prepare failed: ', $statement);
            $self->{logger}->logdie('SQL prepare failed: ', $self->{dbh}->errstr);
        }

        foreach ( @bind_params ) {
            $sth->bind_param( $_, 0.0, SQL_FLOAT );
        }

        $self->{cached_statement} = { $statement => $sth } unless $args{nocache} or $self->{nocache};
    }

    error_handler_messages() unless $args{no_error_handling};

    my $nr_rows;
    unless ( $nr_rows = $sth->execute(@bind_values) ) {
        my $errstr = $sth->errstr || '';
        $self->{logger}->error('SQL excute failed: ', $errstr);
        if ( $self->{error_handler} == 2 ) {
            my @messages = error_handler_messages();
            $self->{logger}->debug( join( "\n", @messages ) ) if @messages;
        }
        return;
    }

    unless ( $args{no_error_handling} ) {
        if ( my @messages = error_handler_messages() ) {
            if ( grep /Truncation error occurred/, @messages ) {
                $self->{logger}->error("truncation error");
                return;
            }
        }
    }

    $sth->finish if $args{nocache} or $self->{nocache};

    return $nr_rows;
}


#---------#
sub query {
#---------#
    my ($self, %args) = @_;

    
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

    unless( $args{quiet} ){
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
        unless ( $sth = $self->{dbh}->prepare($query) ) {
            $self->{logger}->error('SQL prepare failed: ', $query);
            $self->{logger}->logdie('SQL prepare failed: ', $self->{dbh}->errstr);
        }
        $self->{cached_query} = { $query => $sth } unless $args{nocache} or $self->{nocache};
    }

    #
    # execute the query
    #
    unless( $args{quiet} ){
        $self->{logger}->debug('executing SQL query');
    }
#    $self->{logger}->debug("bind values: @bind_values") if @bind_values;
    unless ( $sth->execute(@bind_values) ) {
        $self->{logger}->error('SQL execute failed: ', $sth->errstr);
        return;
    }
    #
    # fetch the results
    #
    my $array_ref;
    while ( 1 ) {
        my $local_array_ref;
        unless ( $local_array_ref = $sth->fetchall_arrayref() ) {
            $self->{logger}->error('SQL fetch failed: ', $sth->errstr);
            return;
        }

        push @{$array_ref}, @{$local_array_ref} if @{$local_array_ref};

        last unless $sth->{syb_more_results};
    }

    if ( wantarray() ) {
        my $names_ref = $sth->{NAME};
        return ($array_ref, $names_ref);
    }
    else {
        return $array_ref;
    }
}

#
# Executes a query which contains embedded go's, for intermediary commits.
# The query is split up and each part is executed separately.
#
#-------------------#
sub composite_query {
#-------------------#
    my ($self, %args) = @_;
   
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

    my @subqueries = split /\ngo\n/, $query;

    my ( $array_ref, $names_ref );
    while ( my $subquery = shift @subqueries ) {
        my $nr_placeholders = ( $subquery =~ tr/?// );
        unless ( $nr_placeholders <= scalar(@bind_values) ) {
            $self->{logger}->error('not enough bind values specified');
            return;
        }
        my @sub_bind_values = splice( @bind_values, 0, $nr_placeholders );
        if ( @subqueries ) {
            return unless $self->do( statement => $subquery, values => \@sub_bind_values );
        }
        else {
            ($array_ref, $names_ref) = $self->query( query => $subquery, values => \@sub_bind_values );
        }
    }

    if ( wantarray() ) {
        return ($array_ref, $names_ref);
    }
    else {
        return $array_ref;
    }
}

#
# Executes a statement which contains embedded go's, for intermediary commits.
# The statement is split up and each part is executed separately.
#
#----------------#
sub composite_do {
#----------------#
    my ($self, %args) = @_;

   
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

    my @substatements = split /\ngo\n/, $statement;

    my $nr_rows;
    while ( my $substatement = shift @substatements ) {
        my $nr_placeholders = ( $substatement =~ tr/?// );
        unless ( $nr_placeholders <= scalar(@bind_values) ) {
            $self->{logger}->error('not enough bind values specified');
            return;
        }
        my @sub_bind_values = splice( @bind_values, 0, $nr_placeholders );
        return unless $nr_rows = $self->do( statement => $substatement, values => \@sub_bind_values );
    }

    return $nr_rows;
}

# does multiple inserts or updates
# 
#---------------#
sub do_multiple {
#---------------#
    my ($self, %args) = @_;

    
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
        $self->{logger}->logdie('SQL prepare failed: ', $self->{dbh}->errstr);
    }

    foreach ( @bind_params ) {
        $sth->bind_param( $_, 0.0, SQL_FLOAT );
    }

    #
    # execute the sql
    #
    $self->{logger}->debug('executing SQL');

    foreach my $row( @{ $args{values} } ){
        my @values = @{ $row };
        unless ( $sth->execute( @values ) ) {
            $self->{logger}->error( "SQL execute failed with bind values @values: ", $sth->errstr );
        }
    }

    return 1;
}

#--------------#
sub drop_table {
#--------------#
        my( $self, $table, $database ) = @_;
        $self->{logger}->logdie( "no table specified" ) unless( $table );
        $database ||= $self->{database};
        $self->do( statement => "if object_id('$database..$table') is not null drop table $table" );
}        

#
# Arguments:
#
# database:    defaults to $self->{database} if not supplied
# file:        full path to the file to bcp in
# table:       table name to bcp into
# format:      format file to use
# delimiter:   defaults to ; if not supplied
#
#----------#
sub bcp_in {
#----------#
    my( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $database = $args{database} || $self->{database};

    my $file;
    unless ( $file = $args{file} ) {
        $logger->logdie("missing argument (file)");
    }

    my $table;
    unless ( $table = $args{table} ) {
        $logger->logdie("missing argument (table)");
    }

    $logger->info("bulk copy $file into $database.$table");

    my $command = $self->bcp_in_command( %args );

    my ( $success, $errorcode, $output ) = Mx::Process->run( command => $command, logger => $logger, config => $config );

    if ( ! $success or $errorcode or $output =~ /failed/ ) {
        $logger->error("bulk copy failed");
        return;
    }

    $logger->info("bulk copy succeeded");

    return 1;
}

#
# Arguments:
#
# database:    defaults to $self->{database} if not supplied
# file:        full path to the file to bcp in
# table:       table name to bcp into
# format:      format file to use
# delimiter:   defaults to ; if not supplied
#
#------------------#
sub bcp_in_command {
#------------------#
    my( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $dsquery    = $self->{dsquery};
    my $database   = $args{database} || $self->{database};
    my $username   = $self->{username};
    my $password   = $self->{password};
    my $delimiter  = $args{delimiter} || '\;';
    my $packetsize = $args{packetsize} || $config->retrieve('SYB_PACKETSIZE');

    my $file;
    unless ( $file = $args{file} ) {
        $logger->logdie("missing argument (file)");
    }

    my $errorfile = $file . '.err';

    my $table;
    unless ( $table = $args{table} ) {
        $logger->logdie("missing argument (table)");
    }

    my $format = $args{format};

    $format = ( $format ) ? " -f $format" : " -t$delimiter";

    my $command =
      $config->retrieve('SYB_DIR') . '/' . $config->retrieve('SYB_OCS') . '/bin/bcp '
      . $database . '.' . $table
      . ' in '
      . $file
      . ' -A ' . $packetsize
      . ' -U' . $username
      . ' -P' . $password
      . ' -S' . $dsquery
      . ' -J iso_1'
      . ' -c'
      . $format
      . ' -e ' . $errorfile;

    return $command;
}

#
# Arguments:
#
# database:    defaults to $self->{database} if not supplied
# file:        full path to the file to bcp out to
# table:       table name to bcp from
# format:      format file to use
# delimiter:   defaults to ; if not supplied
#
#-----------#
sub bcp_out {
#-----------#
    my( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $database = $args{database} || $self->{database};

    my $file;
    unless ( $file = $args{file} ) {
        $logger->logdie("missing argument (file)");
    }

    my $table;
    unless ( $table = $args{table} ) {
        $logger->logdie("missing argument (table)");
    }

    $logger->info("bulk copy $database.$table into $file");

    my $command = $self->bcp_out_command( %args );

    my ( $success, $errorcode, $output ) = Mx::Process->run( command => $command, logger => $logger, config => $config );

    if ( ! $success or $errorcode or $output =~ /failed/ ) {
        $logger->error("bulk copy failed");
        return;
    }

    $logger->info("bulk copy succeeded");

    return 1;
}

#
# Arguments:
#
# database:    defaults to $self->{database} if not supplied
# file:        full path to the file to bcp out to
# table:       table name to bcp from
# delimiter:   defaults to ; if not supplied
#
#-------------------#
sub bcp_out_command {
#-------------------#
    my( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $dsquery    = $self->{dsquery};
    my $database   = $args{database} || $self->{database};
    my $username   = $self->{username};
    my $password   = $self->{password};
    my $delimiter  = $args{delimiter} || '\;';
    my $packetsize = $args{packetsize} || $config->retrieve('SYB_PACKETSIZE');

    my $file;
    unless ( $file = $args{file} ) {
        $logger->logdie("missing argument (file)");
    }

    my $errorfile = $file . '.err';

    my $table;
    unless ( $table = $args{table} ) {
        $logger->logdie("missing argument (table)");
    }

    my $format = $args{format};

    $format = ( $format ) ? " -f $format" : " -t$delimiter";

    my $command =
      $config->retrieve('SYB_DIR') . '/' . $config->retrieve('SYB_OCS') . '/bin/bcp '
      . $database . '.' . $table
      . ' out '
      . $file
      . ' -A ' . $packetsize
      . ' -U' . $username
      . ' -P' . $password
      . ' -S' . $dsquery
      . ' -J iso_1'
      . ' -c'
      . ' -T ' . 200 * 1024
      . $format
      . ' -e ' . $errorfile;

    return $command;
}

#
# Arguments:
#
# rows:         array ref containing all result rows
# names:        array ref containing all column names
# file:         full path to the csv file
# separator:    separator used in the csv file (optional, default is comma)
# quoted:       boolean indicating if all fields must be quoted (optional, default is false) 
#
#----------#
sub to_csv {
#----------#
    my ($self, %args) = @_;

    my $logger = $self->{logger};
    $logger->debug('creating csv file ', $args{file});
    unless ( $args{rows} and ref($args{rows}) eq 'ARRAY' ) {
        $logger->error('missing or incorrect argument (rows)');
        return; 
    }
    my @rows = @{$args{rows}};
    unless ( $args{names} and ref($args{names}) eq 'ARRAY' ) {
        $logger->error('missing or incorrect argument (names)');
        return; 
    }
    my $names     = $args{names};
    my $quoted    = $args{quoted} || 0;
    my $separator = $args{separator} || CSV_SEPARATOR;
    my $csv       = Text::CSV_XS->new( { binary => 1, always_quote => $quoted, sep_char => $separator } );
    my $method    = $args{append} ? '>>' : '>';
    my $fh;
    unless ( $fh = IO::File->new( $args{file}, $method ) ) {
        $logger->error('cannot open csv file ', $args{file}, ": $!");
        return;
    }
    my $count = -1;
    foreach my $row ( $names, @rows ) {
        if ( $csv->combine( @{$row} ) ) {
            print $fh $csv->string() . CSV_EOL;
            $count++;
        }
        else {
            my $err = $csv->error_input();
            $logger->error("csv combine failed: $err");
        }
    }
    $fh->close();
    $logger->debug("csv file created, $count row(s) written");
    return 1;
}

#
# kills all connections to a particular database
#
#------------#
sub kill_all {
#------------#
    my ($self, $database, $user, $program) = @_;


    my $logger = $self->{logger};

    #
    # if no database is given as argument, take the one stored in the object (if present)
    #
    $database ||= $self->{database};
    unless ( $database ) {
        $logger->error("no database specified");
        return;
    }

    if ( $user ) {
        $logger->debug("trying to kill all connections to $database for user $user");
    }
    else {
        $logger->debug("trying to kill all connections to $database");
    }

    #
    # check which spid's are connected to this particular database
    #
    my $result;
    if ( $program ) {
        unless ( $result = $self->query( query => 'select spid from master..sysprocesses where db_name(dbid)=? and suser_name(suid)=? and spid <> ? and program_name = ?', values => [ $database, $user, $self->{spid}, $program ] ) ) { 
            $logger->error("cannot get list of connections to $database for user $user and program $program");
            return;
        }
    } 
    elsif ( $user ) {
        unless ( $result = $self->query( query => 'select spid from master..sysprocesses where db_name(dbid)=? and suser_name(suid)=? and spid <> ?', values => [ $database, $user, $self->{spid} ] ) ) { 
            $logger->error("cannot get list of connections to $database for user $user");
            return;
        }
    }
    else {
        unless ( $result = $self->query( query => 'select spid from master..sysprocesses where db_name(dbid)=? and spid <> ?', values => [ $database, $self->{spid} ] ) ) { 
            $logger->error("cannot get list of connections to $database");
            return;
        }
    }

    my @spids = map { $_->[0] } @{$result};
    if ( @spids ) {
        $logger->debug("list of connections to $database: @spids");
    }
    else {
        $logger->debug("no connections to $database found");
        return 1;
    }

    #
    # build the kill statement...
    #
    my $statement = join( "\n", map { "kill $_" } @spids );

    #
    # ...and execute it
    #
    if ( $self->do( statement => $statement ) ) {
        $logger->debug("all connections to $database killed");
        return 1;
    }
    else {
        $logger->error("cannot kill the connections to $database");
        return;
    }
}

#--------#
sub kill {
#--------#
    my ($self, $spid) = @_;

    $self->{logger}->debug("trying to kill connection with spid $spid");
    if ( $self->do( statement => "kill $spid" ) ) {
        $self->{logger}->debug("connection with spid $spid killed");
        return 1;
    }
    else {
        $self->{logger}->error("cannot kill the connection with spid $spid");
        return;
    }
}

#--------------------#
sub show_connections {
#--------------------#
    my ($self, $database) = @_;
    
    #
    # if no database is given as argument, take the one stored in the object (if present)
    #
    $database ||= $self->{database};
    unless ( $database ) {
        $self->{logger}->error("no database specified");
        return;
    }
    #
    # check which spid's are connected to this particular database
    #
    my $result;
    unless ( $result = $self->query( query => "select spid,status,suid,hostname,program_name,hostprocess,cmd,cpu,physical_io,memusage,blocked,time_blocked from master..sysprocesses where db_name(dbid)='$database'" ) ) { 
        $self->{logger}->error("cannot get list of connections to $database");
        return;
    }
    my @connections;
    foreach my $connection ( @{$result} ) {
        my %connection;
        $connection{database}     = $database;
        $connection{spid}         = _rtrim($connection->[0]);
        $connection{status}       = _rtrim($connection->[1]);
        $connection{suid}         = _rtrim($connection->[2]);
        $connection{hostname}     = _rtrim($connection->[3]);
        #
        # if the hostname is FQDN, strip off the domain name
        # 
        $connection{hostname}     =~ s/^(\w+)\..*$/$1/;
        $connection{program_name} = _rtrim($connection->[4]);
        $connection{hostprocess}  = _rtrim($connection->[5]);
        $connection{cmd}          = _rtrim($connection->[6]);
        $connection{cpu}          = _rtrim($connection->[7]);
        $connection{physical_io}  = _rtrim($connection->[8]);
        $connection{memusage}     = _rtrim($connection->[9]);
        $connection{blocked}      = _rtrim($connection->[10]);
        $connection{time_blocked} = _rtrim($connection->[11]);
        push @connections, \%connection;
    }
    return @connections;
}

#---------------#
sub connections {
#---------------#
    my ( $self ) = @_;


    my $query = "
      select
        spid,
        rtrim(status),
        suser_name(suid),
        rtrim(hostname),
        rtrim(program_name),
        rtrim(hostprocess),
        rtrim(cmd),
        cpu,
        physical_io,
        memusage,
        blocked,
        rtrim(tran_name),
        time_blocked,
        db_name(dbid),
        network_pktsz,
        loggedindatetime
      from master..sysprocesses";

    my $result;
    unless ( $result = $self->query( query => $query ) ) { 
        $self->{logger}->error("cannot get list of connections to database");
        return;
    }

    return @{$result};
}

#--------------#
sub show_locks {
#--------------#
    my ($self, $database) = @_;

   
    my $current_database = $self->database;

    if ( $database ne $current_database ) {
        $self->use( $database );
    }
 
    my $result;
    unless ( $result = $self->query( query => "select l.spid, p.suid, p.hostname, p.hostprocess, p.program_name, o.name, v.name from master..syslocks l, master..sysprocesses p, sysobjects o, master..spt_values v where p.spid = l.spid and l.type = v.number and v.type = 'L' and o.id = l.id and db_name(p.dbid) = ? and l.spid <> ?", values => [ $database, $self->{spid} ] ) ) {
        $self->{logger}->error("cannot get list of locks in $database");
        $self->use( $current_database );
        return;
    }

    my @locks;
    foreach my $lock ( @{$result} ) {
        my %lock;
        $lock{database}     = $database;
        $lock{spid}         = _rtrim($lock->[0]);
        $lock{suid}         = _rtrim($lock->[1]);
        $lock{hostname}     = _rtrim($lock->[2]);
        $lock{hostprocess}  = _rtrim($lock->[3]);
        $lock{program_name} = _rtrim($lock->[4]);
        $lock{object_name}  = _rtrim($lock->[5]);
        $lock{lock_type}    = _rtrim($lock->[6]);
        push @locks, \%lock;
    }

    if ( $database ne $current_database ) {
        $self->use( $current_database );
    }

    return @locks;
}

#---------#
sub locks {
#---------#
    my ( $self, $database ) = @_;


    my $current_database = $self->database;

    if ( $database ne $current_database ) {
        $self->use( $database );
    }

    my $query = "
      select
        l.spid,
        db_name(p.dbid),
        suser_name(p.suid),
        rtrim(p.hostname),
        rtrim(p.program_name),
        rtrim(p.hostprocess),
        rtrim(p.cmd),
        o.name,
        v.name
      from
        master..syslocks l,
        master..sysprocesses p,
        master..spt_values v,
        sysobjects o
      where
        l.spid <> ? and
        l.spid = p.spid and
        db_name(p.dbid) = ? and
        l.id = o.id and
        l.type = v.number and
        v.type = 'L'";
        

    my $result;
    unless ( $result = $self->query( query => $query, values => [ $self->{spid}, $database ] ) ) { 
        $self->{logger}->error("cannot get list of locks in database $database");
        return;
    }

    if ( $database ne $current_database ) {
        $self->use( $current_database );
    }

    return @{$result};
}

#---------------------#
sub table_column_info {
#---------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $database = $args{database} || $config->DB_NAME;

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $database = $1;
        $table    = $2;
    }

    my $current_database = $self->database;
    if ( $database ne $current_database ) {
        $self->use( $database );
    }

    my $sth;
    unless ( $sth = $self->{dbh}->column_info( $database, '%', $table, '%' ) ) {
        $logger->error("cannot retrieve column info for table $table ($database): " . $self->{dbh}->errstr);
        $self->use( $current_database );
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

    if ( $database ne $current_database ) {
        $self->use( $current_database );
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
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $database = $args{database} || $config->DB_NAME;

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $database = $1;
        $table    = $2;
    }

    my @columns    = $self->table_column_info( table => $table, database => $database );
    my $nr_columns = @columns;

    my $ddl = "create table $table (\n";

    my $count = 0;
    foreach my $column ( @columns ) {
        $count++;

        $ddl .= $column->{name} . ' ';

        if ( $column->{name} eq 'TIMESTAMP' and $column->{type} eq 'varbinary' and $column->{length} == 8 and $column->{nullable} ) {
            $ddl .= 'timestamp';
        }
	elsif ( $column->{type} eq 'numeric' or $column->{type} eq 'decimal' ) {
            $ddl .= $column->{type} . '(' . $column->{length} . ',' . $column->{precision} . ')';
        }
	elsif ( $column->{type} eq 'numeric identity' ) {
            $ddl .= 'numeric(' . $column->{length} . ',' . $column->{precision} . ') identity';
        }
        elsif ( $column->{type} eq 'varchar' or $column->{type} eq 'char' or $column->{type} eq 'varbinary' ) {
            $ddl .= $column->{type} . '(' . $column->{length} . ')';
        }
        else {
            $ddl .= $column->{type};
        }

        unless ( $column->{type} =~ /identity/ ) {
            $ddl .= ( $column->{nullable} ) ? ' null' : ' not null';
        }

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

    my $database;
    unless ( $database = $args{database} ) {
        $logger->error("no database specified");
        return;
    }

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $table = $2;
    }

    my ( $indexes_ref ) = Mx::Sybase::Index2->retrieve_existing_indexes( tables => [ $table ], database => $database, sybase => $self, config => $config, logger => $logger );

    return values %{$indexes_ref};
}

#--------------------#
sub table_space_info {
#--------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $table;
    unless ( $table = $args{table} ) {
        $logger->error("no table specified");
        return;
    }

    my $database = $args{database} || $config->DB_NAME;

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $database = $1;
        $table    = $2;
    }

    my $current_database = $self->database;
    if ( $database ne $current_database ) {
        $self->use( $database );
    }

    my %info = ();
    if ( my $used_ref = $self->query( query => "sp_spaceused $table", quiet => 1 ) ) {
        if ( my @params = @{ $used_ref->[0] } ) {
            if ( defined $params[1] ) {
                ( $info{ nr_rows } )  = $params[1] =~ /(\d+)/;
                ( $info{ reserved } ) = $params[2] =~ /(\d+)/;
                ( $info{ data } )     = $params[3] =~ /(\d+)/;
                ( $info{ indexes } )  = $params[4] =~ /(\d+)/;
                ( $info{ unused } )   = $params[5] =~ /(\d+)/;
            }
        }
    }

    if ( $database ne $current_database ) {
        $self->use( $current_database );
    }

    return %info;
}

#-------------------#
sub table_size_info {
#-------------------#
    my ( $self, $table ) = @_;


    my $config   = $self->{config};
    my $logger   = $self->{logger};

    my $database = $config->DB_NAME;

    unless ( $table ) {
        $logger->error("no table specified");
        return;
    }

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $database = $1;
        $table    = $2;
    } 

    my $current_database = $self->database;
    if ( $database ne $current_database ) {
        $self->use( $database );
    }

    my $result;
    unless ( $result = $self->query( query => "select id from sysobjects where name = ?", values => [ $table ], quiet => 1 ) ) {
        $logger->error("cannot determine table existence");
        $self->use( $current_database );
        return;
    }

    unless ( $result->[0][0] ) {
        $self->use( $current_database );
        return;
    }

    unless ( $result = $self->query( query => "select count(*) from $table", quiet => 1 ) ) {
        $logger->error("cannot determine table size");
        $self->use( $current_database );
        return;
    }

    if ( $database ne $current_database ) {
        $self->use( $current_database );
    }

    return $result->[0][0];
}

#-----------------#
sub table_extract {
#-----------------#
    my ( $self, $table ) = @_;


    unless ( $table ) {
        $self->{logger}->error("no table specified");
        return;
    }

    my $config   = $self->{config};
    my $database = $config->DB_NAME;

    if ( $table =~ /^([^.]+)\.\.([^.]+)$/ ) {
        $database = $1;
        $table    = $2;
    } 

    my $current_database = $self->database;
    if ( $database ne $current_database ) {
        $self->use( $database );
    }

    my $rows_ref = $self->query( query => "select top 10 * from $table" ); 

    if ( $database ne $current_database ) {
        $self->use( $current_database );
    }

    return @{$rows_ref};
}

#--------------#
sub all_tables {
#--------------#
    my ( $self, %args ) = @_;


    my $config      = $self->{config};
    my $database    = $args{database} || $config->DB_NAME;
    my $tableowner  = $args{owner}    || '%';

    my @tables = $self->{dbh}->tables( $database, $tableowner, '%', 'TABLE' );

    return @tables;
}

#-----------------#
sub all_databases {
#-----------------#
    my ( $self ) = @_;

    my $result;
    unless ( $result = $self->query( query => 'select name from master..sysdatabases' ) ) {
        $self->{logger}->error("cannot retrieve database list");
        return;
    }
    return map { $_->[0] } @{$result};
}

#------------------#
sub translate_suid {
#------------------#
    my ( $self, $suid ) = @_;
    
    my $result;
    unless ( $result = $self->query( query => 'select name from master..syslogins where suid=?', values => [ $suid ] ) ) { 
        $self->{logger}->error("cannot translate suid $suid");
        return;
    }
    return $result->[0][0];
}

#--------------#
sub checkpoint {
#--------------#
    my ($self) = @_;

    $self->{logger}->debug('performing checkpoint');
    unless ( $self->{dbh}->do('checkpoint') ) {
        $self->{logger}->error('checkpoint failed: ', $self->{dbh}->errstr);
        return;
    }
}


#--------#
sub spid {
#--------#
    my ($self) = @_;

    return $self->{spid};
}

#------------#
sub database {
#------------#
    my ($self) = @_;


    unless( $self->{database} ) {
        ( $self->{database} ) = $self->{dbh}->selectrow_array( 'select db_name()' );
    }

    return $self->{database};
}

#-----------#
sub version {
#-----------#
    my ($self) = @_;

    my $result = $self->query( query => 'select @@version' );
    return $result->[0][0];
}

#--------------#
sub nr_engines {
#--------------#
    my ($self) = @_;

    my $result = $self->query( query => 'select count(*) from master..sysengines' );
    return $result->[0][0];
}

#--------------------#
sub server_page_size {
#--------------------#
    my ($self) = @_;

    my $result = $self->query( query => 'select @@maxpagesize' );
    return $result->[0][0];
}

#-------------------#
sub max_connections {
#-------------------#
    my ($self) = @_;

    my $result = $self->query( query => 'sp_configure "number of user connections"' );
    return $result->[0][4];
}

#-----------------#
sub sp_helpdevice {
#-----------------#
    my ($self) = @_;

    my $result = $self->query( query => 'sp_helpdevice' );
    return $result;
}

#----------------#
sub sp_configure {
#----------------#
    my ($self) = @_;

    my $result = $self->query( query => 'sp_configure' );
    return $result;
}

#--------------------#
sub sp_monitorconfig {
#--------------------#
    my ($self) = @_;

    my $result = $self->query( query => 'sp_monitorconfig "all"' );
    return $result;
}

#--------------------------#
sub runnable_process_count {
#--------------------------#
    my ($self) = @_;

    my $result = $self->query( query => 'sp_configure "runnable process search count"' );
    return $result->[0][4];
}

#----------#
sub uptime {
#----------#
    my ($self) = @_;

    my $result = $self->query( query => 'select @@boottime' );
    return $result->[0][0];
}

#-------------#
sub size_info {
#-------------#
    my ( $self, $database ) = @_;


    my %info = ();

    my $result = $self->query( query => "sp_helpdb $database" );

    my $total_data_size_mb = 0; my $total_log_size_mb = 0; my $free_data_size_kb = 0; my $free_log_size_kb = 0;
    foreach my $row ( @{$result} ) {
        if ( $row->[2] =~  /^data only\s+$/ or $row->[2] =~ /^data and log\s+$/ ) {
            $total_data_size_mb += $row->[1];
            $free_data_size_kb  += $row->[4];
        }
        elsif ( $row->[2] =~  /^log only\s+$/ ) {
            $total_log_size_mb += $row->[1];
        }

        if ( $row->[0] =~ /log only free kbytes = (\d+)/ ) {
            $free_log_size_kb = $1;
        }
    }

    $info{total_data_size_gb} = sprintf "%.2f", $total_data_size_mb / 1024;
    $info{total_log_size_gb}  = sprintf "%.2f", $total_log_size_mb / 1024;
    $info{free_data_size_gb}  = sprintf "%.2f", $free_data_size_kb / ( 1024 * 1024 );
    $info{free_log_size_gb}   = sprintf "%.2f", $free_log_size_kb / ( 1024 * 1024 );

    return %info;
}

#-------------------#
sub connection_info {
#-------------------#
    my ( $self ) = @_;


    my %info = ();

    my $result = $self->query( query => "select db_name(dbid), suser_name(suid), count(suid) from master..sysprocesses group by dbid, suid" );

    foreach my $row ( @{$result} ) {
        my $dbname   = $row->[0];
        my $username = $row->[1];
        my $count    = $row->[2];

        $info{$dbname}->{$username} = $count;
        $info{$dbname}->{total}    += $count;
        $info{total}->{total}      += $count;
    }

    return %info;
}

#------------#
sub sql_text {
#------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $spid;
    unless ( $spid = $args{spid} ) {
        $logger->logdie('sql_text: missing argument (spid)');
    }

    my $result = $self->query( query => "select SequenceInBatch, SQLText from master..monSysSQLText where SPID = ?", values => [ $spid ], quiet => 1 );

    my @sql_text; my $sql_text;
    if ( $result ) {
        foreach my $row ( @{$result} ) {
            my ( $sequence_nr, $text ) = @{$row};
            if ( $sequence_nr == 1 ) {
                push @sql_text, $sql_text if $sql_text;
                $sql_text = $text;
            }
            else {
                $sql_text .= $text;
            }
        }

        push @sql_text, $sql_text if $sql_text;
    }

    $result = $self->query( query => "select SQLText from master..monProcessSQLText where SPID = ?", values => [ $spid ], quiet => 1 );

    if ( $result ) {
        $sql_text = '';
        foreach my $row ( @{$result} ) {
            $sql_text .= $row->[0];
        }

        push @sql_text, $sql_text if $sql_text;
    }

    return @sql_text;
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
    # remove REPBATCH tables
    #
    $sql_text =~ s/REPBATCH#PL_\d+#\d+_DBF//g;

    #
    # remove newlines and whitespace
    #
    $sql_text =~ s/\s//g;

    #
    # remove string values
    #
    $sql_text =~ s/'.*?'//g;
    $sql_text =~ s/".*?"//g;

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
    $self->{logger}->debug( 'Sybase connection to ', $self->{dsquery}, ' as user ', $self->{username}, ' closed' );
    return 1;
}

#-----------#
sub is_open {
#-----------#
    my ( $self ) = @_;


    return ( $self->{status} == OPEN );
}

#--------------------------#
sub error_handler_messages {
#--------------------------#
    my ($self) = @_;

    my @messages = @ERROR_HANDLER_MESSAGES;
    @ERROR_HANDLER_MESSAGES = ();
    return @messages
}

#------------#
sub avg_load {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('avg_load: missing argument (config)');
    }

    my $syb_loadfile = $config->SYB_LOADFILE;

    unless ( -f $syb_loadfile ) {
        $logger->error("avg_load: $syb_loadfile does not exist");
        return 0;
    }

    my $mtime = ( stat $syb_loadfile )[9]; 

    if ( time() - $mtime > 120 ) {
        $logger->error("avg_load: $syb_loadfile is older than 2 minutes");
        return 0;
    }

    my $fh;
    unless ( $fh = IO::File->new( $syb_loadfile, '<' ) ) {
        $logger->error("avg_load: cannot open $syb_loadfile: $!");
        return 0;
    }

    my $avg_load = <$fh>;

    $fh->close();

    return $avg_load;
} 

#
# Function used to handle PRINT statments in Transact-SQL, for
# handling messages from the Backup Server, showplan, output, dbcc output, etc.
# This subroutine has been taken from the DBD::Sybase documentation.
#
#------------------#
sub _error_handler {
#------------------#
    my ( $err, $sev, $state, $line, $server, $proc, $msg, $sql, $err_type ) = @_;

    chomp($msg);
    my @msg;
    if ( $err_type eq 'server' ) {
        @msg = (
            'Server message:',
            sprintf( 'Message number: %ld, Severity %ld, State %ld, Line %ld', $err, $sev, $state, $line),
            ( defined($server)   ? "Server '$server' " : '' ) . ( defined($proc) ? "Procedure '$proc'" : '' ),
            "Message String: $msg",
        );
        push @ERROR_HANDLER_MESSAGES, $msg;
    }
    else {
        @msg = (
            'Open Client Message:',
            sprintf( 'Message number: %ld, Severity %ld', $err, $sev ),
            "Message String: $msg",
        );
        push @ERROR_HANDLER_MESSAGES, $msg;
    }
    ( $main::_default_logger->is_debug ) ? $main::_default_logger->debug( join( "\n", @msg ) ) : $main::_default_logger->info($msg);
    return 0;    ## CS_SUCCEED
}

#--------------------#
sub _error_handler_2 {
#--------------------#
    my ( $err, $sev, $state, $line, $server, $proc, $msg, $sql, $err_type ) = @_;

    chomp($msg);
    push @ERROR_HANDLER_MESSAGES, $msg;
    return 0;    ## CS_SUCCEED
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

__END__

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    

# Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

					    
=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT


A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

					
=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.


=head1 AUTHOR

<Author name(s)>

