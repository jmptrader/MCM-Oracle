package Mx::Message;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Util;
use Carp;

#
# Attributes:
#
# id
# type
# priority
# environment
# destination
# timestamp
# validity
# message
#

our $TYPE_USER        = 'user';
our $TYPE_ENVIRONMENT = 'environment';

our $PRIO_LOW         = 'low';
our $PRIO_MEDIUM      = 'medium';
our $PRIO_HIGH        = 'high';
our $PRIO_CRITICAL    = 'critical';

our $DEFAULT_VALIDITY = -1;

my $FIELD_SEPARATOR   = '###';


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $db_audit;
    unless ( $db_audit = $self->{db_audit} = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of Murex message (db_audit)");
    }

    unless ( $self->{destination} = $args{destination} ) {
        $logger->logdie("missing argument in initialisation of Murex message (destination)");
    }

    my $type = $args{type} || $TYPE_ENVIRONMENT;
    unless ( $type eq $TYPE_USER or $type eq $TYPE_ENVIRONMENT ) {
        $logger->logdie("wrong message type specified: $type");
    }
    $self->{type} = $type;

    unless ( $self->{message} = $args{message} ) {
        $logger->logdie("missing argument in initialisation of Murex message (message)");
    }

    my $priority = $args{priority} || $PRIO_LOW;
    unless ( $priority eq $PRIO_LOW or $priority eq $PRIO_MEDIUM or $priority eq $PRIO_HIGH or $priority eq $PRIO_CRITICAL ) {
        $logger->logdie("wrong message priority specified: $priority");
    }
    $self->{priority} = $priority;

    my $validity = $args{validity} || $DEFAULT_VALIDITY;
    unless ( $validity =~ /^\-?\d+$/ ) {
        $logger->logdie("wrong message validity specified: $validity");
    }
    $self->{validity} = $validity;

    $self->{environment}  = $args{environment} || $ENV{MXENV};
    $self->{timestamp}    = $args{timestamp}   || time();
    $self->{delivery_ids} = [];

    $self->{id} = $args{id};

    bless $self, $class;

    return $self;
}

#---------------------------------#
sub retrieve_unprocessed_messages {
#---------------------------------#
    my ( $self, %args ) = @_;


    my @messages = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in retrieval of Murex messages (db_audit)");
    }

    foreach my $row ( $db_audit->retrieve_unprocessed_messages() ) {
        if ( my $message = Mx::Message->new(
          id          => $row->[0],
          type        => $row->[1],
          priority    => $row->[2],
          environment => $row->[3],
          destination => $row->[4],
          timestamp   => $row->[5],
          validity    => $row->[6],
          message     => $row->[7],
          db_audit    => $db_audit,
          logger      => $logger
        ) ) {
            push @messages, $message;
        }
    }

    return @messages;
}

#-----------------#
sub set_processed {
#-----------------#
    my ( $self ) = @_;


    $self->{db_audit}->update_processed_message( id => $self->{id} );
}

#--------#
sub send {
#--------#
    my ( $self, %args ) = @_;


    my $db_audit = $self->{db_audit};

    $self->{id} = $db_audit->record_message(
      type        => $self->{type},
      priority    => $self->{priority},
      environment => $self->{environment},
      destination => $self->{destination},
      timestamp   => $self->{timestamp},
      validity    => $self->{validity},
      message     => $self->{message}
    );
}

#-----------------#
sub set_delivered {
#-----------------#
    my ( $self, %args ) = @_;


    my $id       = $self->{id};
    my $username = $args{username};

    push @{$self->{delivery_ids}}, $self->{db_audit}->record_message_delivery( message_id => $id, username => $username, delivered => 1, timestamp => time() );
}

#-------------------#
sub set_undelivered {
#-------------------#
    my ( $self, %args ) = @_;


    my $id       = $self->{id};
    my $username = $args{username};

    $self->{db_audit}->record_message_delivery( message_id => $id, username => $username, delivered => 0, timestamp => time() );
}

#-----------------#
sub set_confirmed {
#-----------------#
    my ( $self ) = @_;


    foreach my $id ( @{$self->{delivery_ids}} ) {
        $self->{db_audit}->record_message_confirmation( delivery_id => $id, delivered => 1, timestamp => time() );
    }
}

#------------------#
sub send_to_client {
#------------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $connection = $args{connection};

    my $environment = $connection->{environment};
    my $username    = $connection->{username};

    $self->{timestamp} = Mx::Util->convert_time_short( $self->{timestamp} );

    my @fields = qw(environment id type priority validity timestamp message);

    my $message = join $FIELD_SEPARATOR, @{ $self }{ @fields };

    eval { $connection->send_utf8( $message ); };

    if ( $@ ) {
        $self->set_undelivered( username => $username );
        $logger->error("sending of message $self->{id} failed (environment: $environment - user: $username)");
        return;
    }
    else {
        $self->set_delivered( username => $username );
        $logger->info("sending of message $self->{id} succeeded (environment: $environment - user: $username)");
        return 1;
    }
}

#------#
sub id {
#------#
    my ( $self ) = @_;


    return $self->{id};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;


    return $self->{type};
}

#---------------#
sub destination {
#---------------#
    my ( $self ) = @_;


    return $self->{destination};
}

#---------------#
sub environment {
#---------------#
    my ( $self ) = @_;


    return $self->{environment};
}

1;
