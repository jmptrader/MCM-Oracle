package Mx::Session::Argument;

use strict;
use warnings;

#
# Fields
#
# name
# nick
# value
# description
# enabled
#

use Carp;

#-------#
sub new {
#-------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of session argument (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of session argument (config)");
    }

    my $nick;
    unless ( $nick = $self->{nick} = $args{nick} ) {
        $logger->logdie("missing argument in initialisation of session argument (nick)");
    }

    my $argument_ref;
    unless ( $argument_ref = $config->retrieve("%SESSIONS%$nick%ARGUMENTS%$name") ) {
        $logger->logdie("argument '$name' is not defined in the configuration file");
    }

    foreach my $param ( qw(value description enabled) ) {
        unless ( exists $argument_ref->{$param} ) {
            $logger->logdie("parameter '$param' for argument '$name' is not defined in the configuration file");
        }
        $self->{$param} = $argument_ref->{$param};
    }

    if ( $self->{enabled} eq 'yes' ) {
        $self->{enabled} = 1;
    }
    elsif ( $self->{enabled} eq 'no' ) {
        $self->{enabled} = 0;
    }
    else {
        $self->{enabled} = undef;

    }

    bless $self, $class;
}  

#--------#
sub list {
#--------#
    my ($class, %args) = @_;


    my @arguments = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $nick;
    unless ( $nick = $args{nick} ) {
        $logger->logdie("missing argument (nick)");
    }

    $logger->debug("scanning the configuration file for arguments for nick '$nick'");

    my $arguments_ref;
    unless ( $arguments_ref = $config->retrieve("%SESSIONS%$nick%ARGUMENTS", 1) ) {
        $logger->warn("cannot access the arguments section for nick '$nick' in the configuration file");
        return ();
    }

    foreach my $name ( keys %{$arguments_ref} ) {
        my $argument = Mx::Session::Argument->new( name => $name, nick => $nick, config => $config, logger => $logger );
        push @arguments, $argument;
    }

    my $nr_arguments = @arguments;

    $logger->debug("found $nr_arguments arguments for nick '$nick' in the configuration file");

    return @arguments;
}

#-------------#
sub all_nicks {
#-------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $sessions_ref;
    unless ( $sessions_ref = $config->retrieve("SESSIONS") ) {
        $logger->logdie("cannot access the sessions section in the configuration file");
    }

    return sort { length($a) <=> length($b) } keys %{$sessions_ref};
}

#----------#
sub update {
#----------#
    my ($class, @list) = @_;


    unless ( @list ) {
        return;
    }

    #
    # 'borrow' the logger, config, and nick from the first object in the list
    #
    my $argument = $list[0];
    unless ( ref($argument) eq 'Mx::Session::Argument' ) {
        croak 'only Mx::Session::Argument objects are allowed as arguments';
    }

    my $logger = $argument->{logger};
    my $config = $argument->{config};
    my $nick   = $argument->{nick};

    my $cfgfile = $config->CONFIGDIR . '/arguments/' . $ENV{MXENV} . '_' . $nick . '.cfg';

    unless ( -f $cfgfile ) {
        return;
    }

    my $fh;
    unless ( $fh = IO::File->new( $cfgfile ) ) {
        $logger->error( "cannot open $cfgfile: $!" );
        return;
    }

    my %enabled = ();

    foreach ( my $line = <$fh> ) {
        if ( $line =~ /^([^:]+):([01])$/ ) { 
            $enabled{$1} = $2;
        }
    }


    $fh->close;

    foreach my $argument ( @list ) {
        if ( ! defined $argument->{enabled} ) { 
            my $name = $argument->{name};
            $argument->{enabled} = $enabled{ $name };
        } 
    } 

    return 1;
}

#-------------#
sub to_string {
#-------------#
    my ( $class, @list ) = @_;


    unless ( @list ) {
        return; 
    }

    my @enabled_list = ();

    foreach my $argument ( @list ) {
        push @enabled_list, $argument if $argument->{enabled};
    }

    join ' ', map { $_->value } @enabled_list;
}

#--------#
sub name {
#--------#
    my ($self) = @_;
 
    return $self->{name};
}

#---------#
sub value {
#---------#
    my ($self) = @_;
 
    return $self->{value};
}

#---------------#
sub description {
#---------------#
    my ($self) = @_;
 
    return $self->{description};
}

#-----------#
sub enabled {
#-----------#
    my ($self) = @_;
 
    return $self->{enabled};
}

1;
