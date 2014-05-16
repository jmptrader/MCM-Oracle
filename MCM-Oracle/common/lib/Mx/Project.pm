package Mx::Project;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;

#
# Attributes:
#
# name                     name of the project
# description              description of the project
# log_retention_days       number of days that logfiles must be kept
# transfer_retention_days  number of days that transferfiles must be kept
#


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};

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
 
    my $project_ref;
    unless ( $project_ref = $config->retrieve("%PROJECTS%$name") ) {
        $logger->logdie("project '$name' is not defined in the configuration file");
    }
 
    foreach my $param (qw( description log_retention_days arch_log_retention_days transfer_retention_days arch_transfer_retention_days )) {
        unless ( exists $project_ref->{$param} ) {
            $logger->logdie("parameter '$param' for project '$name' is not defined in the configuration file");
        }
        $self->{$param} = $project_ref->{$param};
    }
 
    bless $self, $class;
}


#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @projects = ();
 
    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
 
    $logger->debug('scanning the configuration file for projects');
 
    my $projects_ref;
    unless ( $projects_ref = $config->PROJECTS ) {
        $logger->logdie("cannot access the projects section in the configuration file");
    }
 
    foreach my $name ( keys %{$projects_ref} ) {
        my $project = Mx::Project->new( name => $name, config => $config, logger => $logger );
        push @projects, $project;
    }
 
    return @projects;
}


#--------#
sub name {
#--------#
    my ( $self ) = @_;
 
    return $self->{name};
}


#---------------#
sub description {
#---------------#
    my ( $self ) = @_;
 
    return $self->{description};
}


#----------------------#
sub log_retention_days {
#----------------------#
    my ( $self ) = @_;
 
    return $self->{log_retention_days} || $self->{config}->LOG_RETENTION_DAYS;
}


#---------------------------#
sub arch_log_retention_days {
#---------------------------#
    my ( $self ) = @_;
 
    return $self->{arch_log_retention_days} || $self->{config}->ARCH_LOG_RETENTION_DAYS;
}


#---------------------------#
sub transfer_retention_days {
#---------------------------#
    my ( $self ) = @_;
 
    return $self->{transfer_retention_days} || $self->{config}->TRANSFER_RETENTION_DAYS;
}


#--------------------------------#
sub arch_transfer_retention_days {
#--------------------------------#
    my ( $self ) = @_;
 
    return $self->{arch_transfer_retention_days} || $self->{config}->ARCH_TRANSFER_RETENTION_DAYS;
}
 

1;
