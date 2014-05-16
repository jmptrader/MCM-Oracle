package Mx::Book;

use strict;
use warnings;

use Mx::Env;
use Mx::Log;
use Mx::Config;
use Mx::SQLLibrary;
use Mx::Sybase;
use Mx::Report;

use Carp;
use IO::File;

#
# members:
#
# name               name of the book
# type               SINGLE or MULTI (a multibook is a book composed of other books)
# mxbooks            list of Murex books this book contains
# bookids            list of corresponding book ids in the database
# batch              name of the batch which is active on this book
# runtime            typical runtime of the batch for this particular book
# status             possible values: READY, RUNNING, FINISHED, FAILED, ABORTED
# nr_runs            nr of times the batch has been run on this book
# starttime          when the batch started for this book
# endtime            when the batch ended for this book
# report             report which is linked to this book 
# reference          to which global report this book is linked
# multibook          boolean indicating if this book can become part of a multibook
# portfolio_id       in case of VaR, the ID of the (possibly combined) portfolio in the Mx database
# ab_session_id
# session_id
#

use constant TYPE_SINGLE  => 1;
use constant TYPE_MULTI   => 2;

my @VALID_BOOKS   = ();
my %RUNTIMES      = ();
my $MAX_RUNTIME   = 0;
my $NR_MULTIBOOKS = 0;
my $RUNTIME_DB    = undef;

#
# Create a new single book. The book will be validated against the Murex db, and the probable runtime will
# be calculated.
#
# arguments:
#
# name          name of the book
# batch         name of the batch
# reference     global reference
# config        a config object
# logger        a logger object
# sybase        a sybase object
# library       a SQL library object
# ab_session_id session id of the autobalance run
#
# following extra arguments can be used to override the defaults in the configfile:
#
# max_concurrency
# multibook_max_size
# sleep_interval
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;

    my $errstr;
    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $errstr = 'missing argument in initialisation of book (config)';
        $logger->error($errstr);
        return;
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $errstr = 'config argument is not of type Mx::Config';
        $logger->error($errstr);
        return;
    }
    $self->{config} = $config;
    $RUNTIME_DB = $config->retrieve("AB_RUNTIME_DB") unless $RUNTIME_DB;
    my $name;
    unless ( $name = $args{name} ) {
        $errstr = 'missing argument in initialisation of book (name)';
        $logger->error($errstr);
        return;
    }
    $self->{name} = $name;
    unless ( $self->{batch} = $args{batch} ) {
        $errstr = 'missing argument in initialisation of book (batch)';
        $logger->error($errstr);
        return;
    }
    unless ( $self->{reference} = $args{reference} ) {
        $errstr = 'missing argument in initialisation of book (reference)';
        $logger->error($errstr);
        return;
    }
    unless ( $self->{sybase} = $args{sybase} ) {
        $errstr = 'missing argument in initialisation of book (sybase)';
        $logger->error($errstr);
        return;
    }
    unless ( $self->{library} = $args{library} ) {
        $errstr = 'missing argument in initialisation of book (library)';
        $logger->error($errstr);
        return;
    }
    unless ( $self->{ab_session_id} = $args{ab_session_id} ) {
        $errstr = 'missing argument in initialisation of book (ab_session_id)';
        $logger->error($errstr);
        return;
    }
    unless ( Mx::Book->validate_book( name => $name, sybase => $self->{sybase}, library => $self->{library}, logger => $logger ) ) {
        $errstr = "$name is not a valid Murex book";
        $logger->error($errstr);
        return;
    }
    $self->{type}         = TYPE_SINGLE;
    $self->{mxbooks}      = [ $name ]; 
    my $runtime           = _retrieve_runtime( $name, $self->{batch}, $self->{sybase}, $logger, $args{timings} ) || $config->retrieve("AB_MULTIBOOK_MAX_BOOKSIZE");
    $self->{runtime}      = $runtime;
    $RUNTIMES{$name}      = $runtime;
    $MAX_RUNTIME          = $runtime if $runtime > $MAX_RUNTIME;
    $self->{starttime}    = undef;
    $self->{endtime}      = undef;
    $self->{multibook}    = 1;
    $self->{report}       = undef;
    $self->{portfolio_id} = 0;
    $self->{status}       = 'READY';
    bless $self, $class;
    if ( my $book_id = $args{id} ) {
        $self->{bookids} = [ $book_id ];
        $self->{nr_runs} = $args{nr_runs};
        $self->db_update();
    }
    else {
        $self->{bookids} = [];
        $self->{nr_runs} = 0;
    }
    return $self;
}

#----------------#
sub restore_book {
#----------------#
    my ( $class, %args ) = @_;

    my $errstr;
    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $errstr = 'missing argument in initialisation of book (config)';
        $logger->error($errstr);
        return;
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $errstr = 'config argument is not of type Mx::Config';
        $logger->error($errstr);
        return;
    }
    $self->{config} = $config;
    $RUNTIME_DB = $config->retrieve("AB_RUNTIME_DB") unless $RUNTIME_DB;
    my $id;
    unless ( $id = $args{id} ) {
        $errstr = 'missing argument in initialisation of book (id)';
        $logger->error($errstr);
        return;
    }
    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $errstr = 'missing argument in initialisation of book (sybase)';
        $logger->error($errstr);
        return;
    }
    $self->{sybase} = $sybase;
    unless ( $self->{library} = $args{library} ) {
        $errstr = 'missing argument in initialisation of book (library)';
        $logger->error($errstr);
        return;
    }
    my $current_db = $sybase->database();
    $sybase->use($RUNTIME_DB);
    my $query  = "select book, batch, reference, ab_session_id, nr_runs, report_id, status from ab_books where id = $id";
    my $result;
    unless ( $result = $sybase->query( query => $query ) ) {
        $logger->error("unable to retrieve book #$id from the database, aborting...");
        $sybase->use($current_db);
        return;
    }
    $sybase->use($current_db);
    my $name               = $result->[0][0];
    $self->{name}          = $name;
    $self->{mxbooks}       = [ $name ]; 
    $self->{bookids}       = [ $id ];
    $self->{batch}         = $result->[0][1];
    $self->{reference}     = $result->[0][2];
    $self->{ab_session_id} = $result->[0][3];
    $self->{nr_runs}       = $result->[0][4];
    $self->{type}          = TYPE_SINGLE;
    my $runtime            = _retrieve_runtime( $name, $self->{batch}, $self->{sybase}, $logger, $args{timings} ) || $config->retrieve("AB_MULTIBOOK_MAX_BOOKSIZE");
    $self->{runtime}       = $runtime;
    $RUNTIMES{$name}       = $runtime;
    $MAX_RUNTIME           = $runtime if $runtime > $MAX_RUNTIME;
    $self->{starttime}     = undef;
    $self->{endtime}       = undef;
    $self->{multibook}     = 1;
    $self->{report}        = undef;
    $self->{portfolio_id}  = 0;
    $self->{status}        = 'READY';
    bless $self, $class;
    $self->db_update();
    return $self;
}

#
# 'Explodes' a combined book into the single books it contains. The argument book is a string, and this function returns
# a list of strings!
#
# arguments:
#
# book      name of the book to explode
# sybase    a sybase object
# library   a SQL library object
#
#-----------#
sub explode {
#-----------#
    my ( $class, %args ) = @_;

    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    #
    # check the arguments
    #
    my @required_args = qw(book sybase library);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in function call ($arg)");
        }
    }
    $logger->info("exploding book " . $args{book});
    my @mxbooks = _explode_book( $args{book}, $args{sybase}, $args{library}, $logger );
    my @result = ( @mxbooks ) ? @mxbooks : ( $args{book} );
    $logger->info("explosion result: @result");
    return @result;
}

#
# Return a list of all the books defined in Murex.
#
# arguments:
#
# sybase    a sybase object
# library   a SQL library object

#-------------#
sub all_books {
#-------------#
    my ( $class, %args ) = @_;
    
    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    #
    # check the arguments
    #
    my @required_args = qw(sybase library);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in function call ($arg)");
        }
    }
    @VALID_BOOKS = _retrieve_valid_books( $args{sybase}, $args{library}, $logger );
    return @VALID_BOOKS;
}

#---------------------#
sub disable_multibook {
#---------------------#
    my ( $self ) = @_;
    
    $self->{multibook} = 0;
}

#
# Add a single book to another book. This last book will then become a 'multibook' if it wasn't one already.
# The book can only be added if the total runtime of the multibook does not exceed certain threshholds.
#
#------------#
sub add_book {
#------------#
    my ( $self, %args ) = @_; 

    my $logger = $self->{logger};
    my $config = $self->{config};
    my $book;
    unless ( $book = $args{book} ) {
        $logger->logdie("missing argument in function call (book)");
    }
    my $max_booksize   = $args{max_booksize};
    my $max_nr_books   = $args{max_nr_books};
    my $max_percentage = $args{max_percentage};
    my $max_runtime    = $args{max_runtime};
    #
    # return if one of the books does not allow to be put inside a multibook
    #
    return unless ( $self->{multibook} && $book->{multibook} );
    #
    # return if the book to be added has a runtime which is too high
    #
    return if $book->runtime() > $max_booksize;
    #
    # return if the multibook has reached its maximum size
    #
    return if $self->nr_books() >= $max_nr_books;
    #
    # return if the total runtime of the multibook is bigger than a certain percentage of the biggest single book
    #
    if ( $max_percentage ) {
        return if ( $self->runtime() + $book->runtime() ) > ( $max_percentage * $MAX_RUNTIME / 100 );
    }
    #
    # return if the total runtime of the multibook is bigger than a certain runtime
    #
    if ( $max_runtime ) {
        return if ( $self->runtime() + $book->runtime() ) > $max_runtime;
    }
    #
    # all conditions are satisfied, so merge the two books
    #
    push @{$self->{mxbooks}}, $book->book_list();
    $self->{runtime} += $book->runtime();
    if ( $self->{type} == TYPE_SINGLE ) {
        $self->{type} = TYPE_MULTI;
        #
        # give the multibook a new name
        #
        $NR_MULTIBOOKS++;
        $self->{name} = 'ABMULTI_' . $NR_MULTIBOOKS;
    }
    return 1;
}

#
# split a multibooks into single books
#
#---------#
sub split {
#---------#
    my ( $self ) = @_;

    my $logger = $self->{logger};
    my $config = $self->{config};
    if ( $self->{type} == TYPE_SINGLE ) {
        return $self;
    }
    $logger->info("splitting " . $self->{name} . " into single books again"); 
    my @booklist = ();
    my @bookid_list = @{$self->{bookids}};
    foreach my $name ( @{$self->{mxbooks}} ) {
        my $book_id = shift @bookid_list; 
        my $book = Mx::Book->new( name => $name, batch => $self->{batch}, ab_session_id => $self->{ab_session_id}, reference => $self->{reference}, config => $config, logger => $logger, sybase => $self->{sybase}, library => $self->{library}, id => $book_id, nr_runs => $self->{nr_runs} );
        push @booklist, $book;
    }
    return @booklist;
}

#-----------------------------#
sub create_combined_portfolio {
#-----------------------------#
    my ( $self ) = @_;
   
    my $logger  = $self->{logger};
    my $config  = $self->{config};
    my $sybase  = $self->{sybase};
    my $library = $self->{library};
    my $name    = $self->{name};
    my @mxbooks = $self->book_list();
    if ( scalar(@mxbooks) > 1 ) {
        my $query   = $library->query('ab_get_unique_portfolio_id');
        my $result;
        unless ( $result = $sybase->query( query => $query ) ) {
            $logger->error("SQL query failed, cannot retrieve unique portfolio id");
            return;
        }
        my $portfolio_id = $result->[0][0];
        my $statement = $library->query('ab_insert_combined_portfolio');
        unless ( $sybase->do( statement => $statement, values => [ $name, $portfolio_id, $name, $name ] ) ) {
            $logger->error("unable to insert combined portfolio $name in the database, aborting...");
            return;
        }
        $statement = $library->query('ab_add_portfolio');
        my $fogroup = $config->retrieve('FOGROUP');
        foreach my $mxbook ( @mxbooks ) {
            unless ( $sybase->do( statement => $statement, values => [ $fogroup, $name, $mxbook ] ) ) {
                $logger->error("unable to add book $mxbook to combined portfolio $name");
                return;
            }
        }
        $self->{portfolio_id} = $portfolio_id;
    }
    else {
        my $query = $library->query('ab_get_portfolio_id');
        my $result;
        unless ( $result = $sybase->query( query => $query, values => [ $name ] ) ) {
            $logger->error("SQL query failed, cannot retrieve unique portfolio id");
            return;
        }
        $self->{portfolio_id} = $result->[0][0];
    }
    return 1;
}


#
# mark the start of the batch on this book
#
#---------#
sub start {
#---------#
    my ( $self, %args ) = @_;

    $self->{session_id} = $args{session_id};
    $self->{starttime}  = time();
    $self->{status}     = 'RUNNING';
    $self->{nr_runs}++;
    $self->db_update();
    $self->db_link_session();
}

#
# mark the end of the batch on this book
#
#----------#
sub finish {
#----------#
    my ( $self ) = @_;

    $self->{endtime} = time();
    $self->{status}  = 'FINISHED';
    $self->db_update();
}

#
# indicates if the book is ready to be processed
#
#---------#
sub ready {
#---------#
    my ( $self ) = @_;

    if ( $self->{status} eq 'READY' ) {
        return 1;
    }
    return;
}

#--------#
sub fail {
#--------#
    my ( $self ) = @_;

    $self->{status} = 'FAILED';
    $self->db_update();
}

#---------#
sub reset {
#---------#
    my ( $self ) = @_;

    $self->{status} = 'READY';
    $self->{starttime} = $self->{endtime} = undef;
    $self->db_update();
}

#---------#
sub abort {
#---------#
    my ( $self ) = @_;

    $self->{status} = 'ABORTED';
    $self->db_update();
}

#
# Return the probable runtime of the book.
#
#-----------#
sub runtime {
#-----------#
    my ( $self ) = @_;

    return $self->{runtime};
}

#----------------#
sub real_runtime {
#----------------#
    my ( $self ) = @_;

    return ( $self->{endtime} - $self->{starttime} );
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#-------------#
sub reference {
#-------------#
    my ( $self ) = @_;

    return $self->{reference};
}

#----------------#
sub portfolio_id {
#----------------#
    my ( $self ) = @_;

    return $self->{portfolio_id};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;

    return $self->{status};
}

#-------------#
sub book_list {
#-------------#
    my ( $self ) = @_;

    return @{$self->{mxbooks}};
}

#---------------#
sub bookid_list {
#---------------#
    my ( $self ) = @_;

    return @{$self->{bookids}};
}

#
# Return the total nr of books in a multibook
#
#------------#
sub nr_books {
#------------#
    my ( $self ) = @_;

    return scalar( @{$self->{mxbooks}} );
}

#-----------#
sub nr_runs {
#-----------#
    my ( $self ) = @_;

    return $self->{nr_runs};
}

#----------#
sub report {
#----------#
    my ( $self, $report ) = @_;

    $self->{report} = $report if $report;
    return $self->{report};
}

#
# Check if a book is defined in Murex.
#
#------------------#
sub validate_book {
#------------------#
    my ( $class, %args ) = @_;

    my $logger  = $args{logger};
    my $sybase  = $args{sybase};
    my $library = $args{library};
    my $name    = $args{name};
    unless ( @VALID_BOOKS ) {
        @VALID_BOOKS = _retrieve_valid_books( $sybase, $library, $logger ); 
    }
    return ( grep /^$name$/, @VALID_BOOKS );
}

#
# Get a list of all the books defined in Murex
#
#-------------------------#
sub _retrieve_valid_books {
#-------------------------#
    my ( $sybase, $library, $logger ) = @_;

    my $query = $library->query('ab_valid_books');
    my $result;
    unless ( $result = $sybase->query( query => $query ) ) {
        $logger->error("SQL query failed, no valid books found");
        return;
    }
    my @books = map { $_->[0] } @{$result};
    return @books;

}

#-----------------#
sub _explode_book {
#-----------------#
    my ( $name, $sybase, $library, $logger ) = @_;

    my $query = $library->query('ab_explode');
    my $result;
    unless ( $result = $sybase->query( query => $query, values => [ $name ] ) ) {
        $logger->error("SQL query failed, cannot explode $name");
        return;
    }
    my @books = map { $_->[0] } @{$result};
    return @books;
}

#
# Save the runtime for future reference
#
#-------------#
sub db_insert {
#-------------#
    my ( $self ) = @_;

    my $logger        = $self->{logger};
    my $ab_session_id = $self->{ab_session_id};
    my $batch         = $self->{batch};
    my $reference     = $self->{reference};
    my $nr_runs       = $self->{nr_runs};
    my $status        = $self->{status};
    my $sybase        = $self->{sybase};
    my $current_db    = $sybase->database();
    $sybase->use($RUNTIME_DB);
    foreach my $mxbook ( $self->book_list() ) {
        my $est_runtime = $RUNTIMES{$mxbook};
        my $statement  = "insert into ab_books (ab_session_id, book, batch, reference, nr_runs, status, est_runtime) values ($ab_session_id, '$mxbook', '$batch', '$reference', $nr_runs, '$status', $est_runtime)";
        unless ( $sybase->do( statement => $statement ) ) {
            $logger->error("unable to insert book $mxbook in the database, aborting...");
            $sybase->use($current_db);
            return;
        }
        my $result = $sybase->query( query => 'select @@identity' );
        my $book_id = $result->[0][0];
        push @{$self->{bookids}}, $book_id;
    }
    $sybase->use($current_db);
    return 1;
}

#-------------------#
sub db_link_session {
#-------------------#
    my ( $self ) = @_;

    my $logger        = $self->{logger};
    my $session_id    = $self->{session_id};
    my $sybase        = $self->{sybase};
    my $current_db    = $sybase->database();
    $sybase->use($RUNTIME_DB);
    my $statement = "insert into ab_books_sessions (book_id, session_id) values (?, ?)";
    foreach my $book_id ( $self->bookid_list() ) {
        unless ( $sybase->do( statement => $statement, values => [ $book_id, $session_id ] ) ) {
            $logger->error("unable to link book #$book_id and session #$session_id, aborting...");
            $sybase->use($current_db);
            return;
        }
    }
    $sybase->use($current_db);
    return 1;
}

#
# Save the runtime for future reference
#
#-------------#
sub db_update {
#-------------#
    my ( $self ) = @_;

    my $logger        = $self->{logger};
    my $starttime     = $self->{starttime};
    my $endtime       = $self->{endtime};
    my $nr_runs       = $self->{nr_runs};
    my $status        = $self->{status};
    my $runtime       = ( $status eq 'FINISHED' ) ? ( int($self->real_runtime() / $self->nr_books() + 0.5) ) : undef;
    my $report_id     = $self->{report}->id if $self->{report};
    my $sybase        = $self->{sybase};
    my $current_db    = $sybase->database();
    $sybase->use($RUNTIME_DB);
    my $statement  = "update ab_books set starttime = ?, endtime = ?, runtime = ?, nr_runs = ?, status = ?, report_id = ? where id = ?";
    foreach my $book_id ( $self->bookid_list() ) {
        unless ( $sybase->do( statement => $statement, values => [ $starttime, $endtime, $runtime, $nr_runs, $status, $report_id, $book_id ] ) ) {
            $logger->error("unable to update book #$book_id in the database, aborting...");
            $sybase->use($current_db);
            return;
        }
    }
    $sybase->use($current_db);
    return 1;
}

#
# calculate the probable runtime for this book
#
#---------------------#
sub _retrieve_runtime {
#---------------------#
    my ( $name, $batch, $sybase, $logger, $timings_session_id ) = @_;

    my $current_db = $sybase->database();
    $sybase->use($RUNTIME_DB);
    my $query;
    if ( $timings_session_id ) {
        $query = "select runtime from ab_books where book = '$name' and batch = '$batch' and status = 'FINISHED' and ab_session_id = $timings_session_id";
    }
    else {
        $query = "select runtime from ab_books where book = '$name' and batch = '$batch' and status = 'FINISHED' order by starttime";
    }
    my $result;
    unless ( $result = $sybase->query( query => $query ) ) {
        $logger->error("SQL query failed, cannot retrieve runtime for batch $batch and book $name");
        $sybase->use($current_db);
        return;
    }
    my @runtimes = map { $_->[0] } @{$result};
    while ( my $runtime = pop @runtimes ) {
        if ( $runtime > 0 ) {
            $sybase->use($current_db);
            return $runtime;
        }
    }
    $logger->warn("no runtime <> 0 could be retrieved for batch $batch and book $name");
    $sybase->use($current_db);
    return;
}

1;
