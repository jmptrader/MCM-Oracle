package Mx::Auth::Right;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Auth::DB;
use Mx::Sybase::ResultSet;
use Mx::Semaphore;
use Carp;

#
# properties:
#
# id
# name
# type
# description
# user_group_id
# environment_id
#

my @TYPES = ( 'monitoring_gui', 'client_menu' );

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    if ( $args{id} ) {
        $self->{id}   = $args{id};
        $self->{name} = $args{name};
    }
    elsif ( $args{name} ) {
        $self->{name} = $args{name};
    }
    else {
        $logger->logdie("missing argument in initialisation of right (id or name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of right (config)");
    }
    $self->{config} = $config;

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in initialisation of right (db)");
    }
    $self->{db} = $db;

    my $type = $self->{type} = $args{type};
    if ( $type && ! grep /^$type$/, @TYPES ) {
        $logger->logdie("$type is not a valid right type");
    }

    $self->{description}    = $args{description};
    $self->{user_group_id}  = $args{user_group_id};
    $self->{environment_id} = $args{environment_id};

    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $db     = $self->{db};

    my $query = 'select id, name, type, description from rights';

    my $query_key; my $value;
    if ( $value = $self->{id} ) {
        $query_key = 'right_select_by_id';
    }
    elsif ( $value = $self->{name} ) {
        $query_key = 'right_select_by_name';
    }

    my $result = $db->query( query_key => $query_key, values => [ $value ] );

    if ( $result->size == 0 ) {
        $logger->error("right $value can not be retrieved");
        return;
    }

    if ( $result->size > 1 ) {
        $logger->error("right $value retrieved more than once");
        return;
    }

    my %hash = $result->next_hash;

    $self->{id}          = $hash{id};
    $self->{name}        = $hash{name};
    $self->{type}        = $hash{type};
    $self->{description} = $hash{description};

    return 1;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in right retrieval (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in right retrieval (db)");
    }

    my $result = $db->query( query_key => 'right_select' );

    my @rights = ();
    while ( my ( $id, $name, $type, $description ) = $result->next ) {
        push @rights, Mx::Auth::Right->new( id => $id, name => $name, type => $type, description => $description, db => $db, logger => $logger, config => $config );
    }

    return @rights;
}

#----------#
sub insert {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};

    my $semaphore = Mx::Semaphore->new( key => 'auth_rights', create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    $self->{id} = $db->next_id( table => 'rights' );

    my @values = ( $self->{id}, $self->{name}, $self->{type}, $self->{description} );

    my $nr_rows = $db->do( statement_key => 'right_insert', values => [ @values ] );

    $semaphore->release();

    return $nr_rows;
}

#----------#
sub update {
#----------#
    my ( $self ) = @_;


    my @values = ( $self->{name}, $self->{type}, $self->{description}, $self->{id} );

    my $nr_rows = $self->{db}->do( statement_key => 'right_update', values => [ @values ] );

    return $nr_rows;
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;


    my $nr_rows = $self->{db}->do( statement_key => 'right_delete', values => [ $self->{id} ] );

    return $nr_rows;
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#--------#
sub name {
#--------#
    my ( $self, $name ) = @_;

    $self->{name} = $name if defined $name;
    return $self->{name};
}

#--------#
sub type {
#--------#
    my ( $self, $type ) = @_;

    $self->{type} = $type if defined $type;
    return $self->{type};
}

#---------#
sub types {
#---------#
    my ( $class ) = @_;

    return sort @TYPES;
}

#---------------#
sub description {
#---------------#
    my ( $self, $description ) = @_;

    $self->{description} = $description if defined $description;
    return $self->{description};
}

#-----------------#
sub user_group_id {
#-----------------#
    my ( $self, $user_group_id ) = @_;

    $self->{user_group_id} = $user_group_id if defined $user_group_id;
    return $self->{user_group_id};
}

#------------------#
sub environment_id {
#------------------#
    my ( $self, $environment_id ) = @_;

    $self->{environment_id} = $environment_id if defined $environment_id;
    return $self->{environment_id};
}

1;
