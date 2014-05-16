package Mx::User2;

use strict;
use warnings;

use Carp;
use Mx::Env;
use Mx::Config;
use Mx::Sybase;

#
# Attributes:
#
# id:                 id (database key)
# name:               userid (Uxxxxx)
# full_name:          full name of user
# password:           user's encrypted password
# environments:       a user based list of environment objects which belong to the user
# groups:             a user based list of group objects which belong to the user
# logger:             a Mx::Logger instance 
# sybase:	      a Mx::Sybase instance
#


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
    my ( $name );

    if ( $args{id} ) {
        $self->{id} = $args{id};
        if ( $args{name} ) {
            $self->{name} = $args{name};
        }
    }
    else {
        unless ( $name = $args{name} ) {
            $logger->logdie("missing argument in initialisation of user (name or id)");
        }
        $self->{name} = uc($name); 
    }
 
    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of user (sybase)");
    }

    $self->{sybase}       = $sybase;
    $self->{full_name}    = $args{full_name}    || '';

    bless $self, $class;

    if ( $args{groups} ) {
        $self->groups( $args{groups}  );
    }

    if ( $args{environments} ) {
        $self->environments( $args{environments}  );
    }

    if ( $args{password} ) {
        $self->set_password( $args{password} );
    }
    else {
        $self->{password} = '';
    }

    return $self;
}


#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;


    #
    # check the arguments
    #

    if ( $args{user} ) {
        return( _retrieve_for_user( user => $args{user} ) );
    }
    elsif ( $args{env} ) {
        return ( _retrieve_for_env( env => $args{env} ) );
    }
    elsif ( $args{group} ) {
        return ( _retrieve_for_group( group => $args{group} ) );
    }
    else {
        croak 'no logger defined';
    }
}

#----------------------#
sub _retrieve_for_user {
#----------------------#
    my ( %args ) = @_;

    #
    # check the arguments
    #

    my ( $user_result, $query, $user, @array );
    
    $user = $args{user} or croak 'no user defined';

    if ( $user->{id} ) {
        $query       = "select id,name,full_name from users where id = ?";
        $user_result = $user->{sybase}->query( query => $query, values => [ $user->{id} ] );
    }
    elsif ( $user->{name} ) {
        $query       = "select id,name,full_name from users where name = ?";
        $user_result = $user->{sybase}->query( query => $query, values => [ $user->{name} ] )
    }
    else {
        $user->{logger}->logdie( "missing property (name or id ) in initialisation: user object" );
    }

    if ( ref( $user_result ) eq 'ARRAY') {
        if ( defined( $user_result->[0] ) ) {
            @array = @{ $user_result->[0] };
            $user->{id}         = $array[0];
            $user->{name}       = $array[1];
            $user->{full_name}  = $array[2];
            return( $user );
        }
        else {
            return;
        }
    }
}

#--------------------#
sub retrieve_for_env {
#--------------------#
    my ( $class, %args ) = @_;

    
    #
    # check the arguments
    #

    my ( $id_result, $query, @id_array, @list, $id_row, $env, $user );    

    $env = $args{env} or croak 'no environment defined';

    $query = "select user_id,max_sessions,override,web_access from user_environment where environment_id = ?";
    $id_result = $env->{sybase}->query( query => $query, values => [ $env->id ] );
    
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result}; 
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                $user = Mx::User2->new( id => $id_row->[0], logger => $env->{logger}, sybase => $env->{sybase} ); 
                if ( Mx::User2->retrieve( user => $user ) ) {
                    push @list, [ $user,  $id_row->[1], $id_row->[2], $id_row->[3] ];
                }
            }
        }
    }

    if ( @list ) {
        if ( $user->environments( @list ) ) { 
            return ( $user );
        }
    }
    else {
        return;
    }
}

#----------------------#
sub retrieve_for_group {
#----------------------#
    my (  %args ) = @_;

  
    # check the arguments
    #

    my ( $id_result, $query, @id_array, @list, $id_row, $group );

    $group = $args{group} or croak 'no group defined'; 

    $query = "select environment_id from environment_group where group_id = ?";
    $id_result = $group->{sybase}->query( query => $query, values => [ $group->id ] );
   
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result};
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                my $user = Mx::User2->new( id => $id_row->[0], logger => $group->{logger}, sybase => $group->{sybase} );
                if ( Mx::User2->retrieve( user => $user ) ) {
                    push @list, [ $user ];
                }
            }
        }
    }

    if ( @list ) {
        if ( $group->users( @list ) ) {
            return( $group );
        }
    }
    else {
        return;
    }
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args)= @_;


    #
    # check the arguments
    #

    my ( $user_result, $query, $user_id, @array, @list );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    $query       = "select id,name,full_name from users"; 
    $user_result = $sybase->query( query => $query );

    if ( ref( $user_result ) eq 'ARRAY' ) {
        @array = @{$user_result};
        if ( ref( $array[0] ) eq 'ARRAY' ) {
            foreach my $row ( @array ) {
                my $user = Mx::User2->new( id           => $row->[0]
                                          ,name         => $row->[1]
                                          ,full_name    => $row->[2]
                                          ,sybase       => $sybase
                                          ,logger       => $logger );

                push @list, $user;
            }
        }
    }
    if ( @list ) {
        return ( @list );
    }
    else {
        return;
    }
} 

#---------#
sub insert{
#---------#
    my ( $self ) = @_;


    my ( $query, @groups, $ins_result ); 

    $query = "select * from users where name = ?";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) { 
        $self->{logger}->logdie( "Insert of user in database not successful: duplicate user name = $self->{name}" );
    }

    $query = "insert into users values (?,?,?)";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name}, $self->{full_name}, $self->{password} ] ) ) {
        $self->{logger}->logdie( "Insert of user in database not successful" );
    }

    my $result = $self->{sybase}->query( query => 'select max(id) from users' );
    $self->{id} = $result->[0][0];

    if ( @groups = $self->groups ) {
        foreach my $group ( @groups ) {
            $query = "insert into user_group values (?,?)";
            unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->id, $group->id ] ) ) {
                $self->{logger}->logdie( "Insert of user group relation in database not successful" );
            }
        }
    }

    return $result->[0][0];
}


#---------#
sub delete{
#---------#
    my ( $self ) = @_;

    
    my ( $del_result );

    my $query = "delete from users where id = ?";
    unless ( $del_result = $self->{sybase}->do( statement => $query, values => [ $self->{id} ] ) ) {
        $self->{logger}->logdie( "Delete of user in database not successful" );
    }

    return $del_result;

}

#----------#
sub update {
#----------#
    my ( $self ) = @_;
    
    my ( @groups, $query, $ins_result, $upd_result, $del_result );

    $query = "update users set name = ?, full_name = ?, password = ? where id = ?";

    unless ( $upd_result = $self->{sybase}->do( statement => $query, values => [ $self->{name}, $self->{full_name}, $self->{password}, $self->{id} ] ) ) {
        $self->{logger}->logdie( "Update of user in database not successful" );
    }

    $query = "delete from user_group where user_id = ?";

    unless ( $del_result = $self->{sybase}->do( statement => $query, values => [ $self->{id} ] ) ) {
            $self->{logger}->logdie( "Delete of user group relation in database not successful" );
    }

    if ( @groups = $self->groups ) {
        foreach my $group ( @groups ) {
            $query = "insert into user_group values (?,?)";
            unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->id, $group->id ] ) ) {
                $self->{logger}->logdie( "Insert of user group relation in database not successful" );
            }
        }
    }

    return $upd_result;

}

#------#
sub id {
#------#
    my ( $self, $id ) = @_;

    
    $self->{id} = $id if defined $id;
    return $self->{id};

}

#--------#
sub name {
#--------#
    my ( $self, $name ) = @_;

    $self->{name} = uc( $name ) if defined $name;
    return $self->{name};
}

#-------------#
sub full_name {
#-------------#
    my ( $self, $full_name ) = @_;


    $self->{full_name} = $full_name if defined $full_name;
    return $self->{full_name};
}

#----------------#
sub environments {
#----------------#
    my ( $self, @environments ) = @_;

   
    $self->{environments} = [ @environments ] if @environments;
    return @{ $self->{environments} };
}

#----------#
sub groups {
#----------#
    my ( $self, @groups ) = @_;

   
    $self->{groups} = [ @groups ] if @groups;
    return @{ $self->{groups} };
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

1;
