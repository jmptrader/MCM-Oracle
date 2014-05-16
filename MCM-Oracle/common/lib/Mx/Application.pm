package Mx::Application;

use strict;
use warnings;

use Carp;
use Mx::Env;
use Mx::Config;
use Mx::Sybase;

#
# Attributes:
#
# id:                 application id (database key)
# name:               application name
# label:              application label (informational label)
# button_label:       application button label 
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

    if ( !defined( $args{id} ) ) {
        my $name;
        unless ( $name = $args{name} ) {
            $logger->logdie("missing argument in initialisation of application (name or id)");
        }

        $self->{name} = uc($name);
    }
    else {
        $self->{id} = $args{id}; 
    }
 
    my $sybase;
    unless ( $sybase = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of application (sybase)");
    }
    $self->{sybase} = $sybase;
    
    $self->{name}         = uc( $args{name} )  || '';
    $self->{label}        = $args{label}       || '';
    $self->{label}        = $args{pillar}      || '';
    $self->{button_label} = $args{samba_read}  || '';

    bless $self, $class;

    return $self;
}


#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;

    #
    # check the arguments
    #

    # If the id was filled out with the new method we will use the id to perform the query
    # If the id was not filled out we will use the name to perform the query

    my ( $app_result, $query, @array );

    if ( $self->{id} ) {
        $query      = "select id,name,label,button_label from applications where id = ?";
        $app_result = $self->{sybase}->query( query => $query, values => [ $self->{id} ] ); 
    }     
    else {
        $query      = "select id,name,label,button_label from applications where name = ?";
        $app_result = $self->{sybase}->query( query => $query, values => [ $self->{name} ] );
    }

    
    if ( ref( $app_result ) eq 'ARRAY') {
        if ( defined( $app_result->[0] ) ) {
            @array = @{$app_result->[0]}; 
            $self->{id}            = $array[0];
            $self->{name}          = $array[1];
            $self->{label}         = $array[2];
            $self->{button_label}  = $array[3];
        }
        else {
            return;
        }
    }

    return $self;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $ class, %args)= @_;


    #
    # check the arguments
    #

    my ( $app_result, $query, $user_id, @array, @list );

    my $logger = $args{logger} or croak 'no logger defined';
    my $sybase = $args{sybase} or croak 'no sybase defined';

    $query      = "select id,name,label,samba_read,samba_write,pillar from environments"; 
    $app_result = $sybase->query( query => $query );

    if ( ref( $app_result ) eq 'ARRAY' ) {
        if ( defined ( $app_result->[0]) ) {
            @array = @{$app_result};
            foreach my $row ( @array ) {
                my $app = Mx::Environment->new( id            => $row->[0]
                                              ,name           => $row->[1]
                                              ,label          => $row->[2]
                                              ,button_label   => $row->[3] );

                push @list, [ $app ];
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

    $query = "select * from applications where name = ?";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) { 
        $self->{logger}->logdie( "Insert of application in database not successful: duplicate application name = $self->{name}" );
    }

    $query = "insert into applications values (?,?,?)";
    unless ( $ins_result = $self->{sybase}->do( statement => $query, values => [ $self->{name}, $self->{label}, $self->{button_label} ] ) ) {
        $self->{logger}->logdie( "Insert of application in database not successful" );
    }

    my $result = $self->{sybase}->query( query => 'select max(id) from applications' );
    $self->{id} = $result->[0][0];

    return $result->[0][0];
}


#---------#
sub delete{
#---------#
    my ( $self ) = @_;

    
    my ( $del_result );

    my $query = "delete from applications where id = ?";
    unless ( $del_result = $self->{sybase}->do( statement => $query, values => [ $self->{id} ] ) ) {
        $self->{logger}->logdie( "Delete of application in database not successful" );
    }

    return $del_result;

}

#----------#
sub update {
#----------#
    my ( $self ) = @_;
  
    
    my ( $query, $upd_result );

    $query = "select * from applications where name = ?";
    if ( $upd_result = $self->{sybase}->do( statement => $query, values => [ $self->{name} ] ) ) {
        $self->{logger}->logdie( "Update of application in database not successful: duplicate application name = $self->{name}" );
    }

 
    $query = "update applications set name = ?, label = ?, button_label= ? where id = ?";
    unless ( $upd_result = $self->{sybase}->do( query => $query, values => [ $self->{name}, $self->{label}, $self->{button_label} ] ) ) {
        $self->{logger}->logdie( "Update of application in database not successful" );
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

#----------------#
sub button_label {
#----------------#
    my ( $self, $button_label ) = @_;


    $self->{button_label} =  $button_label if defined $button_label;
    return $self->{button_label};
}

1;
