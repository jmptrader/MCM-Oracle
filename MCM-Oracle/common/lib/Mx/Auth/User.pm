package Mx::Auth::User;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Auth::DB;
use Mx::Database::ResultSet;
use Mx::Semaphore;
use Carp;

#
# properties:
#
# id
# name
# first_name
# last_name
# password
# location
# type
# config_data
# disabled
# %groups
# %rights
# all_rights_initialized
#

my @TYPES     = ( 'support', 'operations', 'development', 'testing', 'risk' ); 
my @LOCATIONS = ( 'London', 'New York', 'Bangalore' );

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
        $self->{name} = lc( $args{name} );
    }
    elsif ( $args{name} ) {
        $self->{name} = lc( $args{name} );
    }
    else {
        $logger->logdie("missing argument in initialisation of user (id or name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    $self->{config} = $config;

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in initialisation of user (db)");
    }
    $self->{db} = $db;

    $self->{first_name}  = $args{first_name};
    $self->{last_name}   = $args{last_name};

    my $location = $self->{location} = $args{location};
    if ( $location && ! grep /^$location$/, @LOCATIONS ) {
        $logger->logdie("$location is not a valid user location");
    }

    my $type = $self->{type} = $args{type};
    if ( $type && ! grep /^$type$/, @TYPES ) {
        $logger->logdie("$type is not a valid user type");
    }

    $self->{config_data} = $args{config_data};
    $self->{disabled}    = $args{disabled};

    $self->{groups} = {};
    $self->{rights} = {};
    $self->{all_rights_initialized} = 0;

    bless $self, $class;

    if ( $args{password} ) {
        $self->set_password( $args{password} );
    }

    return $self;
}

#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $db     = $self->{db};

    my $query_key; my $value;
    if ( $value = $self->{id} ) {
        $query_key = 'user_select_by_id';
    }
    elsif ( $value = $self->{name} ) {
        $query_key = 'user_select_by_name';
    }

    my $result = $db->query( query_key => $query_key, values => [ $value ] );

    if ( $result->size == 0 ) {
        $logger->error("user $value can not be retrieved");
        return;
    }

    if ( $result->size > 1 ) {
        $logger->error("user $value retrieved more than once");
        return;
    }
      
    my %hash = $result->next_hash;

    $self->{id}          = $hash{id};
    $self->{name}        = $hash{name};
    $self->{first_name}  = $hash{first_name};
    $self->{last_name}   = $hash{last_name};
    $self->{password}    = $hash{password};
    $self->{location}    = $hash{location};
    $self->{type}        = $hash{type};
    $self->{config_data} = $hash{config_data};
    $self->{disabled}    = ( $hash{disabled} eq 'Y' ) ? 1 : 0;
   
    return 1; 
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in user retrieval (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in user retrieval (db)");
    }

    my $result = $db->query( query_key => 'user_select' );

    my @users = ();
    while ( my ( $id, $name, $first_name, $last_name, $password, $location, $type, $config_data, $disabled ) = $result->next ) {
        push @users, Mx::Auth::User->new( id => $id, name => $name, first_name => $first_name, last_name => $last_name, password => $password, location => $location, type => $type, config_data => $config_data, disabled => $disabled, db => $db, logger => $logger, config => $config );
    }

    return @users;
}

#-----------------------#
sub retrieve_full_names {
#-----------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in user retrieval (db)");
    }

    my $result = $db->query( query_key => 'user_select' );

    my %users = ();
    while ( my ( $id, $name, $first_name, $last_name ) = $result->next ) {
        $first_name ||= '';
        $last_name  ||= '';
        $users{$name} = $first_name . ' ' . $last_name;
    }

    return %users;
}

#----------#
sub insert {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};

    my $semaphore = Mx::Semaphore->new( key => 'auth_users', create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    $self->{id} = $db->next_id( table => 'users' );

    my $disabled = ( $self->{disabled} ) ? 'Y' : 'N';

    my @values = ( $self->{id}, $self->{name}, $self->{first_name}, $self->{last_name}, $self->{password}, $self->{location}, $self->{type}, $self->{config_data}, $disabled );

    my $nr_rows = $db->do( statement_key => 'user_insert', values => [ @values ] );

    $semaphore->release();

    return $nr_rows;
}

#----------#
sub update {
#----------#
    my ( $self ) = @_;


    my $disabled = ( $self->{disabled} ) ? 'Y' : 'N';

    my @values = ( $self->{name}, $self->{first_name}, $self->{last_name}, $self->{password}, $self->{location}, $self->{type}, $self->{config_data}, $disabled, $self->{id} );

    my $nr_rows = $self->{db}->do( statement_key => 'user_update', values => [ @values ] );

    return $nr_rows;
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;


    my $nr_rows = $self->{db}->do( statement_key => 'user_delete', values => [ $self->{id} ] );

    return $nr_rows;
}

#----------------#
sub set_password {
#----------------#
    my ( $self, $password ) = @_;


    my $salt = join '', ('.','/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    $self->{password} = crypt( $password, $salt );
}

#------------------#
sub check_password {
#------------------#
    my ( $self, $password ) = @_;


    my $encrypted_password = $self->{password};
    $password = crypt($password, $encrypted_password);
    if ( $password eq $encrypted_password ) {
        return 1;
    }
    return 0;
}

#----------#
sub groups {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};
    my %groups = %{$self->{groups}};

    if ( %groups ) {
        return values %groups;
    }

    my $result = $db->query( query_key => 'user_group_select', values => [ $self->{id} ] );

    while ( my ( $id, $name, $type, $description, $config_data ) = $result->next ) {
        my $group = Mx::Auth::Group->new( id => $id, name => $name, type => $type, description => $description, config_data => $config_data, db => $db, logger => $logger, config => $config );

        $groups{$id} = $group;
    }

    $self->{groups} = { %groups };

    return values %groups;
}

#--------------#
sub set_groups {
#--------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $db        = $self->{db};
    my $user_id   = $self->{id};
    my $group_ids = $args{group_ids};

    unless ( $group_ids ) {
        $logger->logdie("missing argument in set_groups (group_ids)");
    }

    my $nr_rows = $db->do( statement_key => 'user_group_delete', values => [ $user_id ] );

    foreach my $group_id ( @{$group_ids} ) {
        $nr_rows =  $db->do( statement_key => 'user_group_insert', values => [ $user_id, $group_id ] );

        unless ( $nr_rows == 1 ) {
            $logger->logdie("cannot link user $user_id to group $group_id");
        }
    }

    $self->{groups} = {};
    $self->{rights} = {};
    $self->{all_rights_initialized} = 0;

    return 1;
}

#----------#
sub rights {
#----------#
    my ( $self, %args ) = @_;


    my $logger      = $self->{logger};
    my $config      = $self->{config};
    my $db          = $self->{db};
    my $rights      = $self->{rights};
    my $environment = $args{environment};

    if ( $environment ) {
        my $id = $environment->id;
        if ( exists $rights->{$id} ) {
            my @rights = ( values %{$rights->{$id}}, values %{$rights->{0}} );
            return @rights;
        }
    }
    elsif ( $self->{all_rights_initialized} ) {
        my @rights;
        foreach my $rights_ref ( values %{$rights} ) {
            push @rights, values %{$rights_ref};
        }
        return @rights;
    }

    $self->groups;
    my @user_group_ids = keys %{$self->{groups}};

    push @user_group_ids, $self->{id};

    my $query_key = ( $environment ) ? 'user_right_select_by_environment' : 'user_right_select';

    my %new_rights; my %new_environments;
    foreach my $user_group_id ( @user_group_ids ) {
        my @values = ( $user_group_id );
        push @values, $environment->id if $environment;
        
        my $result = $db->query( query_key => $query_key, values => \@values );

        while ( my ( $right_id, $environment_id, $config_data, $name, $type, $description ) = $result->next ) {
            my $right = Mx::Auth::Right->new( id => $right_id, name => $name, type => $type, description => $description, user_group_id => $user_group_id, environment_id => $environment_id, config_data => $config_data, db => $db, logger => $logger, config => $config );

            $new_environments{$environment_id} = 1;
            $new_rights{$right_id} = $right;
        }
    }

    foreach my $environment_id ( keys %new_environments ) {
        $rights->{$environment_id} = {};
    }

    my @rights = values %new_rights;
    foreach my $right ( @rights ) {
        my $name           = $right->name;
        my $environment_id = $right->environment_id;
        $rights->{$environment_id}->{$name} = $right;
    }

    unless ( $environment ) {
        $self->{all_rights_initialized} = 1;
    }

    return @rights;
}

#---------------#
sub check_right {
#---------------#
    my ( $self, %args ) = @_;


    my $logger      = $self->{logger};
    my $name        = $args{name};
    my $environment = $args{environment};

    unless ( $name ) {
        $logger->logdie("missing argument in user right check (name)");
    }

    my $environment_id = ( $environment ) ? $environment->id : 0;

    $self->rights( environment => $environment );

    if ( my $right = $self->{rights}->{$environment_id}->{$name} || $self->{rights}->{0}->{$name} ) {
        return $right;
    }

    return;
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

#--------------#
sub first_name {
#--------------#
    my ( $self, $first_name ) = @_;

    $self->{first_name} = $first_name if defined $first_name;
    return $self->{first_name};
}

#-------------#
sub last_name {
#-------------#
    my ( $self, $last_name ) = @_;

    $self->{last_name} = $last_name if defined $last_name;
    return $self->{last_name};
}

#-------------#
sub full_name {
#-------------#
    my ( $self ) = @_;

    return $self->{first_name} . ' ' . $self->{last_name};
}

#------------#
sub location {
#------------#
    my ( $self, $location ) = @_;

    $self->{location} = $location if defined $location;
    return $self->{location};
}

#-------------#
sub locations {
#-------------#
    my ( $class ) = @_;

    return sort @LOCATIONS;
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
sub config_data {
#---------------#
    my ( $self, $config_data ) = @_;

    $self->{config_data} = $config_data if defined $config_data;
    return $self->{config_data};
}

#------------#
sub disabled {
#------------#
    my ( $self, $disabled ) = @_;

    $self->{disabled} = $disabled if defined $disabled;
    return $self->{disabled};
}

1;
