package Mx::Environment;

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
# label:              environment label (informational label)
# pillar:             environment pillar (T,S,A or P)
# samba_read:         samba read path for this environment
# samba_write:        samba write path for this environment
# sys_user:           murex system login user (e.g. murex8)
# servers:            hostnames for servers
# users:              a list of users for this environment
# groups:             a list of grous for this environment
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
        $logger->logdie("missing argument in initialisation of environment (sybase)");
    }

    if ( $args{id} ) {
        $self->{id}   = $args{id};
    }
    else {
        my $name;
        unless ( $name = $args{name} ) {
            $logger->logdie( "missing argument in initialisation of user (name or id)" );
        }

        $self->{name} = uc($name);
    }

    $self->{sybase}       = $sybase;
    $self->{label}        = $args{label}       || '';
    $self->{pillar}       = $args{pillar}      || '';
    $self->{samba_read}   = $args{samba_read}  || '';
    $self->{samba_write}  = $args{samba_write} || '';
    $self->{sys_user}     = $args{sys_user}    || '';
    $self->{servers}      = $args{servers}     || [];
    $self->{users}        = $args{users}       || [];
    $self->{groups}       = $args{groups}      || [];

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

    if ( $args{env} ) {
        return( _retrieve_for_env( env => $args{env}, logger => $logger, sybase => $sybase ) ); 
    }
    elsif ( $args{user} ) {
        return ( _retrieve_for_user( user => $args{user}, logger => $logger, sybase => $sybase ) );
    }
    elsif ( $args{group} ) {
        return ( _retrieve_for_group( group => $args{group}, logger => $logger, sybase => $sybase ) );
    }
    else {
        $logger->logdie("missing argument in initialisation of retrieve function: environment object, user object or group object");
    }
}

#---------------------#
sub _retrieve_for_env {
#---------------------#
    my ( %args ) = @_;

 
    #
    # check the arguments
    #

    my ( $env_result, $query, $env, @array );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    unless( $env = $args{env} ) {
        $logger->logdie( "missing argument in initialisation: environment object" );
    } 

    if ( $env->{id} ) {
        $query      = "select id,name,label,samba_read,samba_write,pillar,sys_user,servers from environments where id = ?";
        $env_result = $sybase->query( query => $query, values => [ $env->{id} ] );
    }
    elsif ( $env->{name} ) {
        $query      = "select id,name,label,samba_read,samba_write,pillar,sys_user,servers from environments where name = ?";
        $env_result = $sybase->query( query => $query, values => [ $env->{name} ] )
    }
    else {
        $logger->logdie( "missing property (name or id ) in initialisation: environment object" );
    }

    if ( ref( $env_result ) eq 'ARRAY') {
        if ( defined( $env_result->[0] ) ) {
            @array = @{$env_result->[0]};
            my @servers         = split(';',$array[7]);
            $env->{id}          = $array[0];
            $env->{name}        = $array[1];
            $env->{label}       = $array[2];
            $env->{samba_read}  = $array[3];
            $env->{samba_write} = $array[4];
            $env->{pillar}      = $array[5];
            $env->{sys_user}    = $array[6];
            $env->{servers}     = [ @servers ];
            return( $env );
        }
        else {
            return;
        }
    }
}

#----------------------#
sub _retrieve_for_user {
#----------------------#
    my ( %args ) = @_;

    
    #
    # check the arguments
    #

    my ( $id_result, $query, @id_array, @list, $id_row, $env_id, $max_sessions, $override, $web_access , $user );    

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    unless( $user = $args{user} ) {
        $logger->logdie( "missing argument in initialisation: user object" );
    }

    $query     = "select environment_id,max_sessions,override,web_access from user_environment where user_id = ?";
    $id_result = $sybase->query( query => $query, values => [ $user->id ] );
    
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result}; 
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                $env_id       = $id_row->[0];
                $max_sessions = $id_row->[1];
                $override     = $id_row->[2];
                $web_access   = $id_row->[3];
                my $env = Mx::Environment->new( id => $env_id, logger => $logger, sybase => $sybase ); 
                if ( Mx::Environment->retrieve( env => $env, logger => $logger, sybase => $sybase ) ) {
                    push @list, [ $env, $max_sessions, $override, $web_access ];    
                }        
            }
        }
    }

    if ( @list ) {
        if ( $user->environments( @list ) ) {  
            return( $user );
        }
    }
    else{
        return;
    }
}

#-----------------------#
sub _retrieve_for_group {
#-----------------------#
    my (  %args ) = @_;

   
    # check the arguments
    #

    my ( $id_result, $query, @id_array, @list, $id_row, $rights, $group );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';
   
    unless( $group = $args{group} ) {
        $logger->logdie( "missing argument in initialisation: group object" );
    }

    $query = "select environment_id,rights from environment_group where group_id = ?";
    $id_result = $sybase->query( query => $query, values => [ $group->id ] );
    
    if ( ref( $id_result ) eq 'ARRAY' ) {
        @id_array = @{$id_result};
        if ( ref( $id_array[0] ) eq 'ARRAY' ) {
            foreach $id_row ( @id_array ) {
                my $env = Mx::Environment->new( id => $id_row->[0], logger => $logger, sybase => $sybase );
                $rights = $id_row->[1];
                if ( Mx::Environment->retrieve( env => $env, logger => $logger, sybase => $sybase ) ) {
                    push @list, [ $env, $rights ];
                }
            }
        }
    }

    if ( @list ) {
        if ( $group->environments( @list ) ) {
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
    my ( $class, %args )= @_;


    #
    # check the arguments
    #

    my ( $env_result, $query, $user_id, @array, @list );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    $query      = "select id,name,label,samba_read,samba_write,pillar,sys_user,servers from environments"; 
    $env_result = $sybase->query( query => $query );

    if ( ref( $env_result ) eq 'ARRAY' ) {
        @array = @{$env_result};
        if ( ref( $array[0] ) eq 'ARRAY' ) {
            foreach my $row ( @array ) {
                my @servers = split(';',$array[7]);
                my $env = Mx::Environment->new( id          => $row->[0]
                                              ,name         => $row->[1]
                                              ,label        => $row->[2]
                                              ,samba_read   => $row->[3]
                                              ,samba_write  => $row->[4]
                                              ,pillar       => $row->[5]
                                              ,sys_user     => $row->[6]
                                              ,servers      => [ @servers ]
                                              ,sybase       => $sybase
                                              ,logger       => $logger );

                push @list, $env;
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

    $query = "select * from environments where name = ?";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) { 
        $self->{logger}->logdie( "Insert of environment in database not successful: duplicate environment name = $self->{name}" );
    }

    $query = "insert into environments values (?,?,?,?,?,?,?)";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name}, $self->{label}, $self->{pillar}, $self->{samba_read}, $self->{samba_write}, $self->{sys_user}, join(';',$self->{servers}) ] ) ) {
        $self->{logger}->logdie( "Insert of environment in database not successful" );
    }

    my $result = $self->{sybase}->query( query => 'select max(id) from environments' );
    $self->{id} = $result->[0][0];

    return $result->[0][0];
}

#---------#
sub delete{
#---------#
    my ( $self ) = @_;

    
    my ( $del_result );

    my $query = "delete from environments where id = ?";
    unless ( $del_result = $self->{sybase}->do( statement => $query, values => [ $self->{id} ] ) ) {
        $self->{logger}->logdie( "Delete of environment in database not successful" );
    }

    return $del_result;

}

#----------#
sub update {
#----------#
    my ( $self ) = @_;
  
    
    my ( $query, $upd_result );

    $query = "select * from environments where name = ?";
    if ( $upd_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) {
        $self->{logger}->logdie( "Update of environment in database not successful: duplicate environment name = $self->{name}" );
    }

    $query = "update environments set name = ?, pillar = ?, samba_read= ?, samba_write = ? , sys_user = ?, servers = ? where id = ?";
    unless ( $upd_result = $self->{sybase}->do( query => $query, values => [ $self->{name}, $self->{pillar}, $self->{samba_read}, $self->{samba_write}, $self->{sys_user}, join(';',$self->{servers}), $self->{id} ] ) ) {
        $self->{logger}->logdie( "Update of environment in database not successful" );
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

#----------#
sub pillar {
#----------#
    my ( $self, $pillar ) = @_;


    $self->{pillar} = uc( $pillar ) if defined $pillar;
    return $self->{pillar};
}

#--------------#
sub samba_read {
#--------------#
    my ( $self, $samba_read ) = @_;


    $self->{samba_read} = $samba_read if defined $samba_read;
    return $self->{samba_read};
}

#---------------#
sub samba_write {
#---------------#
    my ( $self, $samba_write ) = @_;


    $self->{samba_write} = $samba_write if defined $samba_write;
    return $self->{samba_write};
}

#-----------#
sub servers {
#-----------#
    my ( $self, @servers ) = @_;


    $self->{servers} = [ @servers ] if @servers;
    return @{ $self->{servers} };
}

#------------#
sub sys_user {
#------------#
    my ( $self, $sys_user ) = @_;


    $self->{sys_user} = $sys_user if defined $sys_user;
    return $self->{sys_user};
}

#---------#
sub users {
#---------#
    my ( $self, @users ) = @_;


    $self->{users} = [ @users ] if @users;
    return @{ $self->{users} };
}

#----------#
sub groups {
#----------#
    my ( $self, @groups ) = @_;


    $self->{groups} = [ @groups ] if @groups;
    return @{ $self->{groups} };
}

1;
