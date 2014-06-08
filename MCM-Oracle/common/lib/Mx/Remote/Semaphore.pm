package Mx::Remote::Semaphore;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Carp;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $self = {};
    $self->{logger} = $logger;

    # 
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of remote semaphore (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of remote semaphore (config)");
    }

    my $semaphore_ref;
    unless ( $semaphore_ref = $config->retrieve("SEMAPHORES.$name") ) {
        $logger->logdie("semaphore '$name' is not defined in the configuration file");
    }

    foreach my $param (qw( type count )) {
        unless ( exists $semaphore_ref->{$param} ) {
            $logger->logdie("parameter '$param' for semaphore '$name' is not defined in the configuration file");
        }
        $self->{$param} = $semaphore_ref->{$param};
    }

    bless $self, $class;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @semaphores = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    $logger->debug('scanning the configuration file for semaphores');

    my $semaphores_ref;
    unless ( $semaphores_ref = $config->SEMAPHORES ) {
        $logger->logdie("cannot access the semaphores section in the configuration file");
    }

    foreach my $name ( keys %{$semaphores_ref} ) {
        my $semaphore = Mx::Remote::Semaphore->new( name => $name, config => $config, logger => $logger );
        push @semaphores, $semaphore;
    }

    return @semaphores;
}


1;
