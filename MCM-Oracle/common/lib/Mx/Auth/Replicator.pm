package Mx::Auth::Replicator;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Alert;
use Mx::Auth::DB;
use IO::Socket;
use Storable qw( thaw );
use Carp;


#
# Attributes:
#
# name:             environment where the receiver runs
# peer_nr:
# hostname:
# port_nr:
# connect_timeout:
# ack_timeout:
# retry_interval:
# disabled
# alert:            alert that must be triggered when the replication fails
#
#
# type
# status
# replication_id
# nr_statements
# total_nr_statements
# next_runtime
# socket 
#


our $STATUS_INITIALIZED     = 1;
our $STATUS_IN_SYNC         = 2;
our $STATUS_OUT_OF_SYNC     = 3;
our $STATUS_SYNCING         = 4;
our $STATUS_CONNECT_FAILED  = 5;
our $STATUS_SEND_FAILED     = 6;
our $STATUS_ACK_FAILED      = 7;
our $STATUS_SQL_FAILED      = 8;

our $TYPE_MASTER            = 'master';
our $TYPE_SLAVE             = 'slave';

my $RECORD_SEPARATOR        = '$$$';
my $FIELD_SEPARATOR         = '###';

our $SYNC_INTERVAL;

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
        $logger->logdie("missing argument in initialisation of replicator (name)");
    }

    $logger->info("initializing replicator '$name'");

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of replicator (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in initialisation of replicator (db)");
    }
    $self->{db} = $db;

    my $type = ( exists $args{type} && $args{type} eq $TYPE_MASTER ) ? $TYPE_MASTER : $TYPE_SLAVE;
    $self->{type} = $type;

    my $replication_configfile = $config->retrieve('AUTH_REPL_CONFIGFILE');
    my $replication_config     = Mx::Config->new( $replication_configfile );

    my $replicator_ref;
    unless ( $replicator_ref = $replication_config->retrieve("%REPLICATORS%$name") ) {
        $logger->error("replicator '$name' is not defined in the configuration file");
        return;
    }

    foreach my $param (qw( peer_nr hostname port_nr connect_timeout ack_timeout retry_interval alert  )) {
        unless ( exists $replicator_ref->{$param} ) {
            $logger->logdie("parameter '$param' for replicator '$name' is not defined in the configuration file");
        }
        $self->{$param} = $replicator_ref->{$param};
    }

    if ( $type eq $TYPE_MASTER ) {
        my $last_replication_id = $db->last_replication_id( peer_nr => $self->{peer_nr} );

        $logger->info("current replication id is $last_replication_id");

        $self->{replication_id} = $last_replication_id;
    }
    else {
        $self->{replication_id} = 0;
    }

    $self->{nr_statements}       = 0;
    $self->{total_nr_statements} = 0;
    $self->{next_runtime}        = time();
    $self->{socket}              = undef;
    $self->{status}              = $STATUS_INITIALIZED;
    $self->{disabled}            = 0;
    $self->{alert}               = Mx::Alert->new( name => 'replication_failure', config => $config, logger => $logger ); 

    $logger->info("replicator '$name' initialized (type: $type)");

    bless $self, $class;

    return $self;
}

#----------------#
sub retrieve_all {
#----------------#
   my ( $class, %args ) = @_;


    my @replicators = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument (db)");
    }

    my $replication_configfile = $config->retrieve('AUTH_REPL_CONFIGFILE');
    my $replication_config     = Mx::Config->new( $replication_configfile );

    unless ( $SYNC_INTERVAL = $replication_config->retrieve('SYNC_INTERVAL') ) {
        $logger->logdie("no sync interval specified in configuration file");
    }

    $logger->debug("scanning the configuration file for replicators");

    my $replicators_ref;
    unless ( $replicators_ref = $replication_config->REPLICATORS ) {
        $logger->logdie("cannot access the replicator section in the configuration file");
    }

    foreach my $name ( keys %{$replicators_ref} ) {
        my $replicator = Mx::Auth::Replicator->new( name => $name, type => $TYPE_MASTER, db => $db, config => $config, logger => $logger );
        push @replicators, $replicator;
    }

    return @replicators;
}

#-----------#
sub in_sync {
#-----------#
    my ( $self, %args ) = @_;


    my $logger         = $self->{logger};
    my $name           = $self->{name};
    my $max_id         = $args{replication_id};
    my $current_id     = $self->{replication_id};


    if ( $current_id == $max_id ) {
        $self->{status} = $STATUS_IN_SYNC;
        return 1;
    } 
    elsif ( $max_id > $current_id ) {
        $self->{status} = $STATUS_OUT_OF_SYNC;
        $logger->debug("replicator '$name' is not in sync (current id $current_id, max id $max_id)");
        return 0;
    }
    else {
        $logger->logdie("syncing anomaly for replicator '$name': current id $current_id, max id $max_id");
    }
}


#--------#
sub sync {
#--------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $db       = $self->{db};
    my $name     = $self->{name};
    my $peer_nr  = $self->{peer_nr};
    my $status   = $self->{status};
    my $type     = $self->{type};
    my $alert    = $self->{alert};

    if ( $type ne $TYPE_MASTER ) {
        $logger->logdie("a replicator of type $type cannot sync");
    } 

    if ( time() < $self->{next_runtime} ) {
        return 1;
    }

    unless ( $status == $STATUS_OUT_OF_SYNC ) {
        $logger->logdie("cannot activate a replicator which is not out of sync");
    }

    $self->{status}        = $STATUS_SYNCING;
    $self->{nr_statements} = 0;

    my $result = $db->statements_to_replicate( peer_nr => $peer_nr );

    my $nr_statements = $result->size;

    if ( $nr_statements == 0 ) {
        $logger->error("replicator $name supposedly out of sync, but no statements found to replicate?");
        $self->{status} = $STATUS_IN_SYNC;
        return 1;
    }

    $logger->debug("replicator '$name': $nr_statements statements to replicate");

    unless ( $self->connect_to_peer ) {
        $self->{status} = $STATUS_CONNECT_FAILED;
        $self->{next_runtime} = time() + $self->{retry_interval};
        my ( $id ) = $result->next_preview;
        $self->{alert}->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $id, $name ], item => $id );
        return;
    }

    while ( my ( $id, $statement_key, $statement_values ) = $result->next ) {
        unless ( $self->send( fields => [ $id, $statement_key, $statement_values ] ) ) {
            $self->{status} = $STATUS_SEND_FAILED;
            $self->{next_runtime} = time() + $self->{retry_interval};
            $self->disconnect_from_peer;
            $self->{alert}->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $id, $name ], item => $id );
            return;
        } 

        my ( $ack_id, $ok );
        unless ( ( $ack_id, $ok ) = $self->receive( timeout => $self->{ack_timeout} ) ) {
            $self->{status} = $STATUS_ACK_FAILED;
            $self->{next_runtime} = time() + $self->{retry_interval};
            $self->disconnect_from_peer;
            $self->{alert}->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $id, $name ], item => $id );
            return;
        }

        unless ( $ack_id == $id && $ok  ) {
            $logger->error("received faulty acknowledge from peer '$name', disabling peer");
            $self->{status}   = $STATUS_SQL_FAILED;
            $self->{disabled} = 1;
            $self->disconnect_from_peer;
            $self->{alert}->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $id, $name ], item => $id );
            return;
        }

        $db->set_sync_status( id => $id, peer_nr => $peer_nr );

        $self->{replication_id} = $id;
        $self->{nr_statements}++;
    }

    $self->{total_nr_statements} += $self->{nr_statements};

    $self->disconnect_from_peer;

    $self->{next_runtime} = time();
    $self->{status}       = $STATUS_IN_SYNC;

    return 1;
}


#----------#
sub listen {
#----------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $db       = $self->{db};
    my $name     = $self->{name};
    my $status   = $self->{status};
    my $type     = $self->{type};

    if ( $type ne $TYPE_SLAVE ) {
        $logger->logdie("a replicator of type $type cannot listen");
    }

    unless ( $self->connect_to_peer ) {
        $logger->error("unable to start listening"); 
        $self->{status} = $STATUS_CONNECT_FAILED;
        return; 
    }

    $self->{status} = $STATUS_SYNCING;

    while ( 1 ) {
        $self->accept;

        while ( my ( $id, $statement_key, $statement_values ) = $self->receive ) {
            my $ok = $db->do( statement_key => $statement_key, values => $statement_values, replicate => 0 );

            unless ( $self->send( fields => [ $id, $ok ] ) ) {
                $logger->error("cannot send acknowledge");
                $self->{status} = $STATUS_ACK_FAILED;
                $self->disconnect_from_peer();
                return;
            }

            unless ( $ok ) {
                $logger->error("sql failure, aborting");
                $self->{status} = $STATUS_SQL_FAILED;
                $self->disconnect_from_peer();
                return;
            }
        }

        $self->disconnect_from_peer( session_only => 1 );
    }
}

#-------------------#
sub connect_to_peer {
#-------------------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $name     = $self->{name};
    my $type     = $self->{type};
    my $hostname = $self->{hostname};
    my $port_nr  = $self->{port_nr};
    my $timeout  = $self->{connect_timeout};

    if ( $type eq $TYPE_MASTER ) {
        my $socket = IO::Socket::INET->new(
          PeerAddr => $hostname,
          PeerPort => $port_nr,
          Proto    => 'tcp',
          Timeout  => $timeout
        );

        unless ( $self->{socket} = $socket ) {
            $logger->error("cannot connect to peer '$name': $!");
            return 0;
        }

        $self->{session} = $socket;

        $logger->debug("connected to peer '$name'"); 
    }
    else {
        my $socket = IO::Socket::INET->new(
          LocalPort => $port_nr,
          Proto     => 'tcp',
          Listen    => 1,
          Reuse     => 1
        );

        unless ( $self->{socket} = $socket ) {
            $logger->error("cannot connect to port $port_nr: $!");
            return 0;
        }

        $logger->debug("listening to port $port_nr"); 
    }

    return 1;
}


#------------------------#
sub disconnect_from_peer {
#------------------------#
    my ( $self, %args ) = @_;


    my $logger       = $self->{logger};
    my $name         = $self->{name};
    my $type         = $self->{type};
    my $port_nr      = $self->{port_nr};
    my $socket       = $self->{socket};
    my $session_only = $args{session_only} || 0;

    if ( $type eq $TYPE_MASTER ) {
        $socket->close();

        $logger->debug("disconnected from peer '$name'");
    }
    else {
        if ( my $session = $self->{session} ) {
            $self->{session}->close();
            $self->{session} = undef;
 
            $logger->debug("session closed");
        }

        unless ( $session_only ) {
            $socket->close();

            $logger->debug("disconnected from port $port_nr");
        }
    }
}


#----------#
sub accept {
#----------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $socket = $self->{socket};

    my $session;
    unless ( $session = $socket->accept ) {
        $logger->logdie("cannot accept new connections: $!");
    }

    my $peerhost = $session->peerhost;

    $logger->debug("incoming connection from $peerhost");

    $self->{session} = $session;

    return 1;
}

#--------#
sub send {
#--------#
    my ( $self, %args ) = @_;

   
    my $logger  = $self->{logger};
    my $session = $self->{session};
    my $name    = $self->{name};
    my $fields  = $args{fields};

    my $message = join $FIELD_SEPARATOR, @{$fields};
    $message .= $RECORD_SEPARATOR;

    my $rc = print $session $message;

    unless ( $rc ) {
        $logger->error("send to peer $name failed");
    }

    return $rc;
}

#-----------#
sub receive {
#-----------#
    my ( $self, %args ) = @_;


    my $logger  = $self->{logger};
    my $session = $self->{session};
    my $name    = $self->{name};
    my $timeout = $args{timeout};

    local $/ = $RECORD_SEPARATOR;

    my $message;
    if ( $timeout ) {
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm $timeout;
            $message = <$session>;
            alarm 0;
        };

        if ( $@ ) {
            $logger->error("read from peer $name timed out");
            return;
        }
    }
    else {
        $message = <$session>;
    }

    return unless $message;

    chomp( $message );

    my @fields = split $FIELD_SEPARATOR, $message;

    return @fields;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;


    return $self->{status};
}

#------------#
sub disabled {
#------------#
    my ( $self ) = @_;


    return $self->{disabled};
}

#-----------#
sub peer_nr {
#-----------#
    my ( $self ) = @_;


    return $self->{peer_nr};
}

#------------#
sub hostname {
#------------#
    my ( $self ) = @_;


    return $self->{hostname};
}

#------------------#
sub replication_id {
#------------------#
    my ( $self ) = @_;


    return $self->{replication_id};
}

#-----------------#
sub nr_statements {
#-----------------#
    my ( $self ) = @_;


    return $self->{nr_statements};
}

1;
