package Mx::Batch;

use strict;

use Mx::GenericScript;
use Mx::Filter;
use Mx::Book;
use Carp;

our @ISA = qw(Mx::GenericScript);

*errstr = *Mx::GenericScript::errstr;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;

    unless ( $args{sybase} ) {
        $args{logger}->logdie("missing argument (sybase)");
    }
    unless ( $args{library} ) {
        $args{logger}->logdie("missing argument (library)");
    }
    my $self = $class->SUPER::new(%args, type => Mx::GenericScript::BATCH);

    $self->_read_config();

    $self->{ab_checked} = 0; # additional member needed for autobalance
    $self->{ab_book} = undef; # the book currently being processed by this batch, also for autobalance
    return $self;
}


#----------------#
sub _read_config {
#----------------#
    my ( $self ) = @_;


    my @files    = ();
    my @tables   = ();
    my @filters  = ();
    my @commands = ();

    my $logger  = $self->{logger};
    my $config  = $self->{config};
    my $sybase  = $self->{sybase};
    my $library = $self->{library};
    my $name    = $self->{name};

    my $batch_configfile = $config->retrieve('BATCH_CONFIGFILE');
    my $batch_config     = Mx::Config->new( $batch_configfile );

    my $batch_ref        = $batch_config->retrieve( "%BATCHES%$name" );
    my $files_ref        = $batch_config->retrieve( "%BATCHES%$name%FILES" );
    my $tables_ref       = $batch_config->retrieve( "%BATCHES%$name%TABLES" );
    my $commands_ref     = $batch_config->retrieve( "%BATCHES%$name%COMMANDS" );

    my $batchname      = $batch_ref->{name};
    my $batchtemplate  = $batch_ref->{template};

    if ( exists $files_ref->{file} ) {
        if ( ref( $files_ref->{file} ) eq 'ARRAY' ) {
            @files = @{$files_ref->{file}};
        }
        else {
            @files = ( $files_ref->{file} );
        }
    }

    if ( exists $tables_ref->{table} ) {
        if ( ref( $tables_ref->{table} ) eq 'ARRAY' ) {
            @tables = @{$tables_ref->{table}};
        }
        else {
            @tables = ( $tables_ref->{table} );
        }
    }

    my $index = -1;
    foreach ( @tables ) {
        $index++;
        my $filter = Mx::Filter->new( label => $name, index => $index, sybase => $sybase, library => $library, config => $config, logger => $logger );
        push @filters, $filter if $filter;
    }

    if ( exists $commands_ref->{command} ) {
        if ( ref( $commands_ref->{command} ) eq 'ARRAY' ) {
            @commands = @{$commands_ref->{command}};
        }
        else {
            @commands = ( $commands_ref->{command} );
        }
    }

    @files    = map { $self->_substitute_placeholders( $_ ) } @files;
    @commands = map { $self->_substitute_placeholders( $_ ) } @commands;

    $self->{batchname}      = $batchname;
    $self->{batchtemplate}  = $batchtemplate;
    $self->{files}          = [ @files ];
    $self->{tables}         = [ @tables ];
    $self->{filters}        = [ @filters ];
    $self->{commands}       = [ @commands ];
}


#----------------------------#
sub _substitute_placeholders {
#----------------------------#
    my ( $self, $string ) = @_;

    
    my $logger = $self->{logger};
    my $config = $self->{config};

    my %params = (
        __ENTITY__  => $self->{entity},
        __RUNTYPE__ => $self->{runtype},
    );

    while ( $string =~ /(__[^_]\w+?[^_]__)/ ) {
        my $before = $`;
        my $ph     = $1;
        my $after  = $';
        my ( $ph2 ) = $ph =~ /__(\w+)__/;    
        if ( exists $params{$ph} ) {
            $string = $before . $params{$ph} . $after;
        }
        elsif ( my $param = $config->retrieve( $ph2, 1 ) ) {
            $string = $before . $param . $after;
        }
        else {
            $logger->logdie("no substitution found for placeholder $ph");
        }
    }

    return $string;
}


#-----------#
sub command {
#-----------#
    my ( $self ) = @_;


    if ( my @commands = @{$self->{commands}} ) {
        return $commands[0];
    }
}


#
# Returns a list of all report batches defined in Murex, corresponding to a certain 'basename'
#
# arguments:
#
# name     basename
# logger   a logger object
# library  a SQL library
# sybase   a sybase object
#
#-------------------------#
sub get_autobalance_names {
#-------------------------#
    my ( $class, %args ) = @_;

    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    #
    # check the arguments
    #
    my @required_args = qw(name sybase library);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in function call ($arg)");
        }
    }
    my $name  = $args{name};
    my $query = $args{library}->query('ab_batches');
    my $result;
    unless ( $result = $args{sybase}->query( query => $query, values => [ $name . '%' ] ) ) {
        $logger->error("SQL query failed, cannot retrieve autobalance names");
        return;
    }
    my @names = ();
    foreach my $batch_name ( map { $_->[0] } @{$result} ) {
        push @names, $batch_name if $batch_name =~ /^$name\d*$/;
    }
    return @names;
}


#
# Defines directly in the database on which books the batch should operate
#
# arguments:
#
# book    Mx::Book object
# sybase  a sybase object
# library a SQL library
#
#----------------#
sub define_books {
#----------------#
    my ( $self, %args ) = @_;

    my $logger = $self->{logger};
    #
    # check the arguments
    #
    my @required_args = qw(book sybase library);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in function call ($arg)");
        }
    }
    $self->{ab_book} = $args{book};
    my $name         = $self->{name};
    my $sybase       = $args{sybase};
    my $library      = $args{library};
    my $query = $library->query("ab_delete_batch");
    unless ( $sybase->do( statement => $query, values => [ $name ] ) ) {
        $logger->error("cannot delete previous batch definition, aborting...");
        return;
    }
    $query = $library->query("ab_define_batch");
    foreach my $book_name ( $args{book}->book_list() ) {
        unless ( $sybase->do( statement => $query, values => [ $name, $book_name ] ) ) {
            $logger->error("cannot insert book $book_name in batch definition, aborting...");
            return;
        }
    }
    return 1;
}

#--------#
sub book {
#--------#
    my ( $self ) = @_;

    return $self->{ab_book};
}

#--------------#
sub is_checked {
#--------------#
    my ( $self, $boolean ) = @_;

    $self->{ab_checked} = $boolean if defined($boolean);
    return $self->{ab_checked};
}

#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $name   = $self->{name};

    my $ref = $config->retrieve( 'EXCLUDE_BATCH', 1 );
    my @exclude_batches = $ref ? @{$ref} : ();

    if ( grep /^$name$/, @exclude_batches ) {
        $logger->info("batch $name is on the exclude list, skipping execution");
        $self->{exitcode} = 1;
        $Mx::Batch::errstr = "batch $name is on the exclude list";
        return;
    }
    else {
        return $self->SUPER::run( %args );
    }
}

1;
