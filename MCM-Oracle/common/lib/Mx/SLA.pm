package Mx::SLA;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;

#
# Attributes:
#
# name           name of the SLA
# type
# warning_value
# breach_value
#

our $OK       = 1;
our $WARNING  = 2;
our $BREACHED = 3;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex collector (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex collector (config)");
    }

    my $type = $args{type};

    my $sla_configfile = $config->retrieve('SLA_CONFIGFILE');
    my $sla_config     = Mx::Config->new( $sla_configfile );

    my $sla_ref;
    unless ( $sla_ref = $sla_config->retrieve("SLAS.$name") ) {
        $logger->logdie("SLA '$name' is not defined in the configuration file");
    }
 
    foreach my $param (qw( type warning_value breach_value )) {
        unless ( exists $sla_ref->{$param} ) {
            $logger->logdie("parameter '$param' for SLA '$name' is not defined in the configuration file");
        }
        $self->{$param} = $sla_ref->{$param};
    }

    if ( $type && $self->{type} ne $type ) {
        return;
    }

    bless $self, $class;

    $self->{warning_value} = $self->_convert_value( $self->{warning_value} ) || return;
    $self->{breach_value}  = $self->_convert_value( $self->{breach_value} )  || return;
 
    return $self;
}


#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my %sla = ();
 
    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $type = $args{type};

    my $sla_configfile = $config->retrieve('SLA_CONFIGFILE');
    my $sla_config     = Mx::Config->new( $sla_configfile );
 
    $logger->debug("scanning the configuration file for SLA's");
 
    my $slas_ref;
    unless ( $slas_ref = $sla_config->SLAS ) {
        $logger->logdie("cannot access the SLA section in the configuration file");
    }
 
    foreach my $name ( keys %{$slas_ref} ) {
        my $sla = Mx::SLA->new( name => $name, type => $type, config => $config, logger => $logger );
        $sla{$name} = $sla if $sla;
    }
 
    return %sla;
}


#---------#
sub check {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $value;
    unless ( $value = $args{value} ) {
        $logger->error("no value supplied for SLA check");
        return;
    }

    $value = $self->_convert_value( $value ) || return $BREACHED;

    if ( $value < $self->{warning_value} && $value < $self->{breach_value} ) {
        return $OK;
    }
    elsif ( $value >= $self->{warning_value} && $value < $self->{breach_value} ) {
        return $WARNING;
    }

    return $BREACHED;
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


#-----------------#
sub warning_value {
#-----------------#
    my ( $self ) = @_;
 
    return $self->{warning_value};
}


#----------------#
sub breach_value {
#----------------#
    my ( $self ) = @_;
 
    return $self->{breach_value};
}

#------------------#
sub _convert_value {
#------------------#
    my ( $self, $value ) = @_;


    my $logger = $self->{logger};
    my $type   = $self->{type};

    my $new_value;
    if ( $type eq 'milestone' ) {
        if ( $value =~ /^(\d+):(\d+):(\d+)$/ ) {
            $new_value = $1 * 3600 + $2 * 60 + $3;
            $new_value += 24 * 3600  if $new_value < 12 * 3600;
        }
    }
    elsif ( $type eq 'runtime' ) {
        if ( $value =~ /^\d+(\.\d+)?$/ ) {
            $new_value = $value;
        }
    }

    unless ( $new_value ) {
        $logger->error("wrong SLA value supplied (type: $type  value: $value)");
        return;
    }

    return $new_value;
}


1;
