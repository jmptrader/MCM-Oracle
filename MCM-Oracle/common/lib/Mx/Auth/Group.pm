package Mx::Auth::Group;

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
# config_data
# %users
# %rights
# all_rights_initialized
#

my @TYPES = ( 'standard' );

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
        $logger->logdie("missing argument in initialisation of group (id or name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of group (config)");
    }
    $self->{config} = $config;

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in initialisation of user (db)");
    }
    $self->{db} = $db;

    my $type = $self->{type} = $args{type};
    if ( $type && ! grep /^$type$/, @TYPES ) {
        $logger->logdie("$type is not a valid group type");
    }

    $self->{description} = $args{description};
    $self->{config_data} = $args{config_data};

    $self->{users}  = {};
    $self->{rights} = {};
    $self->{all_rights_initialized} = 0;

    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $db     = $self->{db};

    my $query_key; my $value;
    if ( $value = $self->{id} ) {
        $query_key = 'group_select_by_id';
    }
    elsif ( $value = $self->{name} ) {
        $query_key = 'group_select_by_name';
    }

    my $result = $db->query( query_key => $query_key, values => [ $value ] );

    if ( $result->size == 0 ) {
        $logger->error("group $value can not be retrieved");
        return;
    }

    if ( $result->size > 1 ) {
        $logger->error("group $value retrieved more than once");
        return;
    }

    my %hash = $result->next_hash;

    $self->{id}          = $hash{id};
    $self->{name}        = $hash{name};
    $self->{type}        = $hash{type};
    $self->{description} = $hash{description};
    $self->{config_data} = $hash{config_data};
    $self->{disabled}    = $hash{disabled};

    return 1;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in group retrieval (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in group retrieval (db)");
    }

    my $result = $db->query( query_key => 'group_select' );

    my @groups = ();
    while ( my ( $id, $name, $type, $description, $config_data ) = $result->next ) {
        push @groups, Mx::Auth::Group->new( id => $id, name => $name, type => $type, description => $description, config_data => $config_data, db => $db, config => $config, logger => $logger );
    }

    return @groups;
}

#----------#
sub insert {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};

    my $semaphore = Mx::Semaphore->new( key => 'auth_groups', create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    $self->{id} = $db->next_id( table => 'groups' );

    my @values = ( $self->{id}, $self->{name}, $self->{type}, $self->{description}, $self->{config_data} );

    my $nr_rows = $db->do( statement_key => 'group_insert', values => [ @values ] );

    $semaphore->release();

    return $nr_rows;
}

#----------#
sub update {
#----------#
    my ( $self ) = @_;


    my @values = ( $self->{name}, $self->{type}, $self->{description}, $self->{config_data}, $self->{id} );

    my $nr_rows = $self->{db}->do( statement_key => 'group_update', values => [ @values ] );

    return $nr_rows;
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;


    my $nr_rows = $self->{db}->do( statement_key => 'group_delete', values => [ $self->{id} ] );

    return $nr_rows;
}

#---------#
sub users {
#---------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};
    my %users  = %{$self->{users}};

    if ( %users ) {
        return values %users;
    }

    my $result = $db->query( query_key => 'group_user_select', values => [ $self->{id} ] );

    while ( my ( $id, $name, $first_name, $last_name, $password, $location, $type, $config_data, $disabled ) = $result->next ) {
        my $user = Mx::Auth::User->new( id => $id, name => $name, first_name => $first_name, last_name => $last_name, password => $password, location => $location, type => $type, config_data => $config_data, disabled => $disabled, db => $db, logger => $logger, config => $config );

        $users{$id} = $user;
    }

    $self->{users} = { %users };

    return values %users;
}

#-------------#
sub set_users {
#-------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $db        = $self->{db};
    my $group_id  = $self->{id};
    my $user_ids  = $args{user_ids};

    unless ( $user_ids ) {
        $logger->logdie("missing argument in set_users (user_ids)");
    }

    my $nr_rows = $db->do( statement_key => 'group_user_delete', values => [ $group_id ] );

    foreach my $user_id ( @{$user_ids} ) {
        $nr_rows =  $db->do( statement_key => 'user_group_insert', values => [ $user_id, $group_id ] );

        unless ( $nr_rows == 1 ) {
            $logger->logdie("cannot link user $user_id to group $group_id");
        }
    }

    $self->{users} = {};

    return 1;
}

#----------#
sub rights {
#----------#
    my ( $self, %args ) = @_;


    my $logger         = $self->{logger};
    my $config         = $self->{config};
    my $db             = $self->{db};
    my %rights         = %{$self->{rights}};
    my $environment_id = $args{environment_id};

    if ( defined $environment_id ) {
        if ( exists $rights{$environment_id} ) {
            my @rights = ( values %{$rights{$environment_id}}, values %{$rights{0}} );
            return @rights;
        }
    }
    elsif ( $self->{all_rights_initialized} ) {
        my @rights;
        foreach my $rights_ref ( values %rights ) {
            push @rights, values %{$rights_ref};
        }
        return @rights;
    }

    my $user_group_id = $self->{id};

    my $query_key = ( defined $environment_id ) ? 'group_right_select_by_environment' : 'group_right_select';

    my %new_rights; my %new_environments;
    my @values = ( $user_group_id );
    push @values, $environment_id if defined $environment_id;

    my $result = $db->query( query_key => $query_key, values => \@values );

    while ( my ( $right_id, $environment_id, $config_data, $name, $type, $description ) = $result->next ) {
        my $right = Mx::Auth::Right->new( id => $right_id, name => $name, type => $type, description => $description, user_group_id => $user_group_id, environment_id => $environment_id, config_data => $config_data, db => $db, logger => $logger, config => $config );

        $new_environments{$environment_id} = 1;
        $new_rights{$right_id} = $right;
    }

    foreach my $environment_id ( keys %new_environments ) {
        $rights{$environment_id} = {};
    }


    my @rights = values %new_rights;
    foreach my $right ( @rights ) {
        my $name           = $right->name;
        my $environment_id = $right->environment_id;
        $rights{$environment_id}->{$name} = $right;
    }

    unless ( defined $environment_id ) {
        $self->{all_rights_initialized} = 1;
    }

    return @rights;
}

#--------------#
sub set_rights {
#--------------#
    my ( $self, %args ) = @_;


    my $logger          = $self->{logger};
    my $config          = $self->{config};
    my $db              = $self->{db};
    my $user_group_id   = $self->{id};
    my $right_ids       = $args{right_ids};
    my $environment_ids = $args{environment_ids};

    unless ( $right_ids ) {
        $logger->logdie("missing argument in set_rights (right_ids)");
    }

    unless ( $environment_ids && @{$environment_ids} ) {
        $logger->logdie("missing argument in set_rights (environment_ids)");
    }

    foreach my $environment_id ( @{$environment_ids} ) {
        $db->do( statement_key => 'group_right_delete', values => [ $user_group_id, $environment_id ] );
    }

    foreach my $environment_id ( @{$environment_ids} ) {
        foreach my $right_id ( @{$right_ids} ) {

            my $nr_rows =  $db->do( statement_key => 'group_right_insert', values => [ $user_group_id, $right_id, $environment_id ] );

            unless ( $nr_rows == 1 ) {
                $logger->logdie("cannot link right $right_id to group $user_group_id and environment $environment_id");
            }
        }
    }

    $self->{rights} = {};
    $self->{all_rights_initialized} = 0;

    return 1;
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

#---------------#
sub config_data {
#---------------#
    my ( $self, $config_data ) = @_;

    $self->{config_data} = $config_data if defined $config_data;
    return $self->{config_data};
}

1;
