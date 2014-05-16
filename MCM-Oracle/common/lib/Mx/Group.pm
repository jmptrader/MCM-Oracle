package Mx::Group;

use strict;
use warnings;

use Carp;
use Mx::Env;
use Mx::Config;
use Mx::Sybase;

#
# Attributes:
#
# id:                 environment id (database key)
# name:               environment name
# type:               group type
# label:              group label
# users:              a list of users for this group
# environments:       a list of environments for this group
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
    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of group (sybase)");
    }

    if ( $args{id} ) {
        $self->{id}   = $args{id};
    }
    else {
        my $name;
        unless ( $name = $args{name} ) {
            $logger->logdie( "missing argument in initialisation of group (name or id)" );
        }

        $self->{name} = uc($name);
    }

    $self->{sybase}       = $sybase; 
    $self->{name}         = uc( $args{name} )   || '';
    $self->{type}         = $args{type}         || '';
    $self->{label}        = $args{label}        || '';
    $self->{users}        = $args{users}        || [];
    $self->{environments} = $args{environments} || [];

    bless $self, $class;

    return $self;
}


#------------#
sub retrieve {
#------------#
    my ( $class, %args ) = @_;

    #
    # check the arguments
    #

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    if ( $args{group} ) {
        return( _retrieve_for_group( group => $args{group}, logger => $logger, sybase => $sybase ) );
    }
    elsif ( $args{user} ) {
        return ( _retrieve_for_user( user => $args{user}, logger => $logger, sybase => $sybase ) );
    }
    elsif ( $args{env} ) {
        return ( _retrieve_for_env( env => $args{env}, logger => $logger, sybase => $sybase ) );
    }
    else {
        $logger->logdie("missing argument in initialisation of retrieve function: environment object, user object or group object");
    }
}

#-----------------------#
sub _retrieve_for_group {
#-----------------------#
    my ( %args ) = @_;


    #
    # check the arguments
    #

    my ( $group_result, $query, $group, @array );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    unless( $group = $args{group} ) {
        $logger->logdie( "missing argument in initialisation: group object" );
    }

    if ( $group->{id} ) {
        $query        = "select id,name,type,label from groups where id = ?";
        $group_result = $sybase->query( query => $query, values => [ $group->{id} ] );
    }
    elsif ( $group->{name} ) {
        $query        = "select id,name,type,label from groups where name = ?";
        $group_result = $sybase->query( query => $query, values => [ $group->{name} ] );
    }
    else {
        $logger->logdie( "missing property (name or id ) in initialisation: group object" );
    }

    if ( ref( $group_result ) eq 'ARRAY') {
        if ( defined( $group_result->[0] ) ) {
            @array = @{$group_result->[0]};
            $group->{id}          = $array[0];
            $group->{name}        = $array[1];
            $group->{type}        = $array[2];
            $group->{label}       = $array[3];
            return( $group );
        }
        else {
            return;
        }
    }
}

#----------------------#
sub _retrieve_for_user {
#----------------------#
    my (  %args ) = @_;

    
    #
    # check the arguments
    #

    my ( $id_result, $query, $user, @id_array, @list, $id_row );    

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';
    
    unless( $user = $args{user} ) {
        $logger->logdie( "missing argument in initialisation: user object" );
    }

    $query = "select group_id from user_group where user_id = ?";
    $id_result = $sybase->query( query => $query, values => [ $user->id ] );
    
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result}; 
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                my $group = Mx::Group->new( id => $id_row->[0], logger => $logger, sybase => $sybase ); 
                if ( Mx::Group->retrieve( group => $group, logger => $logger, sybase => $sybase ) ) {
                    push @list, [ $group ];
                }
            }
        }
    }

    if ( @list ) {
        if ( $user->groups( @list ) ) {
            return( $user );
        }
    }
     else {
        return;
    }
}

#---------------------#
sub _retrieve_for_env {
#---------------------#
    my ( %args ) = @_;

   
    #
    # check the arguments
    #

    my ( $id_result, $query, $env, @id_array, @list, $id_row );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';
   
    unless( $env = $args{env} ) {
        $logger->logdie( "missing argument in initialisation: environment object" );
    }

    $query = "select group_id,rights from environment_group where environment_id = ?";
    $id_result = $sybase->query( query => $query, values => [ $env->id ] );
    
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result};
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                my $group = Mx::Group->new( id => $id_row->[0], logger => $logger, sybase => $sybase );
                if ( Mx::Group->retrieve( group => $group, logger => $logger, sybase => $sybase ) ) {
                    push @list, [ $group, $id_row->[1] ];
                }
            }
        }
    }

    if ( @list ) {
        if ( $env->groups ( @list ) ) {
            return ( @list );
        }
    }
    else {
        return;
    }
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $ class, %args)= @_;


    #
    # check the arguments
    #

    my ( $group_result, $query, $user_id, @array, @list );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    $query      = "select id,name,type,label from groups"; 
    $group_result = $sybase->query( query => $query );

    if ( ref( $group_result ) eq 'ARRAY' ) {
        @array = @{$group_result};
        if ( ref( $array[0] ) eq 'ARRAY' ) {
            foreach my $row ( @array ) {
                my $group = Mx::Group->new( id      => $row->[0]
                                           ,name    => $row->[1]
                                           ,type    => $row->[2]
                                           ,label   => $row->[3]
                                           ,logger  => $logger
                                           ,sybase  => $sybase );

                push @list, $group;
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


    my ( $query, $ins_result ); 

    $query = "select * from groups where name = ?";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) { 
        $self->{logger}->logdie( "Insert of groups in database not successful: duplicate group name = $self->{name}" );
    }

    $query = "insert into groups values (?,?,?)";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name}, $self->{type}, $self->{label} ] ) ) {
        $self->{logger}->logdie( "Insert of group in database not successful" );
    }

    my $result = $self->{sybase}->query( query => 'select max(id) from groups' );
    $self->{id} = $result->[0][0];

    return $result->[0][0];
}


#---------#
sub delete{
#---------#
    my ( $self ) = @_;

    
    my ( $del_result );

    my $query = "delete from groups where id = ?";
    unless ( $del_result = $self->{sybase}->do( statement => $query, values => [ $self->{id} ] ) ) {
        $self->{logger}->logdie( "Delete of group in database not successful" );
    }

    return $del_result;

}

#----------#
sub update {
#----------#
    my ( $self ) = @_;
  
    my ( $query, $upd_result );

    $query = "select * from groups where name = ?";
    if ( $upd_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) {
        $self->{logger}->logdie( "Update of groups in database not successful: duplicate group name = $self->{name}" );
    }
 
    $query = "update groups set name = ?, pillar = ?, samba_read= ?, samba_write = ? where id = ?";
    unless ( $upd_result = $self->{sybase}->do( query => $query, values => [ $self->{name}, $self->{pillar}, $self->{samba_read}, $self->{samba_write}, $self->{id} ] ) ) {
        $self->{logger}->logdie( "Update of group in database not successful" );
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

#---------#
sub label {
#---------#
    my ( $self, $label ) = @_;


    $self->{label} = $label if defined $label;
    return $self->{label};
}

#--------#
sub type {
#--------#
    my ( $self, $type ) = @_;


    $self->{type} = uc( $type ) if defined $type;
    return $self->{type};
}

#----------------#
sub environments {
#----------------#
    my ( $self, @environments ) = @_;


    $self->{label} = [ @environments ] if @environments;
    return @{ $self->{environments} };
}

#---------#
sub users {
#---------#
    my ( $self, @users ) = @_;


    $self->{label} = [ @users ] if  @users;
    return @{ $self->{users} };
}

1;
