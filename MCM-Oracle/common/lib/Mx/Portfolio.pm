package Mx::Portfolio;

use strict;

use Carp;

our $TYPE_SINGLE   = 'S';
our $TYPE_COMBINED = 'C';
our $TYPE_NODE     = 'N';

#
# properties:
#
# name
# type
#
 
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;
 
 
    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex portfolio (config)");
    }

    my $sybase;
    unless ( $sybase = $self->{sybase} = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of Murex portfolio (sybase)");
    }

    my $library;
    unless ( $library = $self->{library} = $args{library} ) {
        $logger->logdie("missing argument in initialisation of Murex portfolio (library)");
    }

    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex portfolio (name)");
    }

    _determine_type( $self );
 
    bless $self, $class;
}


#-------------------#
sub _determine_type {
#-------------------#
    my ( $self ) = @_;


    my $logger  = $self->{logger};
    my $sybase  = $self->{sybase};
    my $library = $self->{library};
    my $name    = $self->{name};

    my $query;
    unless ( $query = $library->query('portfolio_type_1') ) {
        $logger->logdie("cannot retrieve query 'portfolio_type_1' from the SQL library");
    }

    my $result;
    unless ( $result = $sybase->query( query => $query, values => [ $name ] ) ) {
        $logger->logdie("cannot determine type of portfolio '$name'");
    }

    if ( @{$result} ) {
        if ( $result->[0][0] == 0 ) {
            $self->{type} = $TYPE_SINGLE;
            $logger->debug("portfolio '$name' is of type '$TYPE_SINGLE'");
            return 1;
        }
        elsif ( $result->[0][0] == 1 ) {
            $self->{type} = $TYPE_COMBINED;
            $logger->debug("portfolio '$name' is of type '$TYPE_COMBINED'");
            return 1;
        }
        else {
            $logger->logdie("got unexpected value as portfolio type for portfolio '$name': " . $result->[0][0]);
        }
        
    }

    unless ( $query = $library->query('portfolio_type_2') ) {
        $logger->logdie("cannot retrieve query 'portfolio_type_2' from the SQL library");
    }

    unless ( $result = $sybase->query( query => $query, values => [ $name ] ) ) {
        $logger->logdie("cannot determine type of portfolio '$name'");
    }

    if ( $result->[0][0] > 0 ) {
        $self->{type} = $TYPE_NODE;
        $logger->debug("portfolio '$name' is of type '$TYPE_NODE'");
        return 1; 
    }
    else {
        $logger->logdie("cannot determine type of portfolio '$name'");
    }
}


#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}


#--------#
sub type {
#--------#
    my ( $self ) = @_;

    return $self->{type};
}

1;
