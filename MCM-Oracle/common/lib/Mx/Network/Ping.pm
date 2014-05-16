package Mx::Network::Ping;

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Network;
use Carp;


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
        $logger->logdie("missing argument in initialisation of network ping (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of network ping (config)");
    }

    my $ping_configfile = $config->retrieve('PING_CONFIGFILE');
    my $ping_config     = Mx::Config->new( $ping_configfile );

    my $ping_ref;
    unless ( $ping_ref = $ping_config->retrieve("%PINGS%$name") ) {
        $logger->logdie("ping '$name' is not defined in the configuration file");
    }

    foreach my $param (qw( ip count size )) {
        unless ( exists $ping_ref->{$param} ) {
            $logger->logdie("parameter '$param' for ping '$name' is not defined in the configuration file");
        }
        $self->{$param} = $ping_ref->{$param};
    }

    $logger->info("ping '$name' initialized");

    bless $self, $class;

    return $self;
}

#----------------#
sub retrieve_all {
#----------------#
   my ( $class, %args ) = @_;


    my @pings = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $ping_configfile = $config->retrieve('PING_CONFIGFILE');
    my $ping_config     = Mx::Config->new( $ping_configfile );

    $logger->debug("scanning the configuration file for network pings");

    my $pings_ref;
    unless ( $pings_ref = $ping_config->PINGS ) {
        $logger->logdie("cannot access the network ping section in the configuration file");
    }

    foreach my $name ( keys %{$pings_ref} ) {
        my $ping = Mx::Network::Ping->new( name => $name, config => $config, logger => $logger );
        push @pings, $ping;
    }

    return @pings;
}

#-----------#
sub execute {
#-----------#
    my ( $self ) = @_;


    my ( $rate, $time ) = Mx::Network->ping( ip => $self->{ip}, count => $self->{count}, size => $self->{size}, logger => $self->{logger}, config => $self->{config} );

    $self->{rate} = $rate;
    $self->{time} = $time;
}

#--------#
sub name {
#--------#
   my ( $self ) = @_;


   return $self->{name};
}

#---------#
sub count {
#---------#
   my ( $self ) = @_;


   return $self->{count};
}

#--------#
sub size {
#--------#
   my ( $self ) = @_;


   return $self->{size};
}

#--------#
sub rate {
#--------#
   my ( $self ) = @_;


   return $self->{rate};
}

#--------#
sub time {
#--------#
   my ( $self ) = @_;


   return $self->{time};
}
    
1;
