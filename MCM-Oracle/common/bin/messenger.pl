#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Util;
use Mx::Message;
use Net::WebSocket::Server;
use POSIX;
use Getopt::Long;

my %CONNECTIONS_BY_ENV = ();
my %CONNECTIONS_BY_ID  = ();
my $CONNECTION_ID      = 1;
my $POLL_INTERVAL      = 5;
my $LAST_POLL_TIME     = 0;

#---------#
sub usage {
#---------#
    print <<EOT
 
Usage: messenger.pl [ -start ] [ -stop ] [ -restart ] [ -help ]
 
 -start    Start the messenger.
 -stop     Stop the messenger.
 -restart  Restart the messenger.
 -help     Display this text.
 
EOT
;
    exit;
}
 
my ($do_start, $do_stop, $do_restart);
 
GetOptions(
    'start'   => \$do_start,
    'stop'    => \$do_stop,
    'restart' => \$do_restart,
    'help'    => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new(directory => $config->LOGDIR, keyword => 'messenger');

if ( $do_stop or $do_restart ) {
    $logger->info("stopping the messenger");

    my $pidfile = Mx::Process->pidfile( descriptor => "messenger", config => $config );

    if ( ! -f $pidfile ) {
        $logger->info("pidfile $pidfile not found, messenger not running");
    }
    elsif ( my $process = Mx::Process->new( pidfile => $pidfile, config => $config, logger => $logger ) ) {
        if ( $process->kill ) {
            $logger->info("messenger killed");
            $process->remove_pidfile();
        }
        else {
            $logger->error("messenger cannot be killed");
        }
    }
    else {
        $logger->warn("pidfile $pidfile present, but no process running");
        unlink( $pidfile );
    }
}

if ( $do_start or $do_restart ) {
    #
    # become a daemon
    #
    my $pid = fork();
    exit if $pid;
    unless ( defined($pid) ) {
        $logger->logdie("cannot fork: $!");
    }

    unless ( setsid() ) {
        $logger->logdie("cannot start a new session: $!");
    }

    close(STDIN);

    my $process = Mx::Process->new( descriptor => 'messenger', logger => $logger, config => $config, light => 1 );
    unless ( $process->set_pidfile( $0, 'messenger' ) ) {
        $logger->logdie("not running exclusively");
    }

    my $logfile = $logger->filename;
    open STDOUT, ">>$logfile";
    open STDERR, ">>$logfile";

    my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

    my $port_nr = $config->MESSENGER_PORT;

    my $last_poll_time = 0; my $connection_id = 1;

    $logger->info("listening on port $port_nr");

    Net::WebSocket::Server->new(
        listen => $port_nr,

        on_connect => sub {
            my ( $serv, $conn ) = @_;

            $conn->on(
                utf8 => sub {
                    my ( $conn, $msg ) = @_;

                    my ( $type, @args ) = split '###', $msg;

                    if ( $type eq 'register' ) {
                        my ( $environment, $username ) = @args;

                        $conn->{environment}   = $environment;
                        $conn->{username}      = $username;
                        $conn->{connection_id} = $connection_id;

                        $CONNECTIONS_BY_ENV{$environment}->{$username}->{$connection_id} = $conn;

                        $logger->info("user $username on $environment registered (connection id $connection_id)");

                        $connection_id++;
                    }
                    elsif ( $type eq 'confirm' ) {
                        my ( $message_id ) = @args;

                        my $environment   = $conn->{environment};
                        my $username      = $conn->{username};
                        my $conn_id       = $conn->{connection_id};

                        if ( my $message = $CONNECTIONS_BY_ID{$conn_id}->{$message_id} ) {
                            $message->set_confirmed();

                            delete $CONNECTIONS_BY_ID{$conn_id}->{$message_id};

                            $logger->info("message $message_id confirmed by user $username on $environment");
                        }
                        else {
                            $logger->error("unable to confirm message $message_id for user $username on $environment");
                        }
                    }
                    else {
                        $logger->error("received invalid message: $msg");
                    }
                },

                pong => sub {
                    if ( time() - $last_poll_time > $POLL_INTERVAL ) {
                        $last_poll_time = time();

                        foreach my $message ( Mx::Message->retrieve_unprocessed_messages( logger => $logger, db_audit => $db_audit ) ) {
                            $message->set_processed();

                            my $id          = $message->id;
                            my $type        = $message->type;
                            my $destination = $message->destination;
                            my $environment = $message->environment;

                            if ( $type eq $Mx::Message::TYPE_USER ) {
                                unless ( $CONNECTIONS_BY_ENV{$environment}->{$destination} ) {
                                    $message->set_undelivered( username => $destination );
                                    next;
                                }

                                my $delivered = 0;
                                foreach my $connection ( values %{$CONNECTIONS_BY_ENV{$environment}->{$destination}} ) {
                                    if ( $message->send_to_client( connection => $connection ) ) {
                                        $CONNECTIONS_BY_ID{ $connection->{connection_id} }->{ $message->id } = $message;
                                        $delivered++;
                                    }
                                }

                                $message->set_undelivered( username => $destination ) unless $delivered;
                            }
                            elsif ( $type eq $Mx::Message::TYPE_ENVIRONMENT ) {
                                my $delivered = 0;
                                foreach my $username ( keys %{$CONNECTIONS_BY_ENV{$destination}} ) {
                                    $logger->debug("trying to deliver message $id to user $username on $destination");

                                    foreach my $connection ( values %{$CONNECTIONS_BY_ENV{$destination}->{$username}} ) {
                                        if ( $message->send_to_client( connection => $connection ) ) {
                                            $CONNECTIONS_BY_ID{ $connection->{connection_id} }->{ $message->id } = $message;
                                            $delivered++;
                                        }
                                    }
                                }

                                $logger->warn("no users connected to $destination to deliver message $id") unless $delivered;
                            }
                            else {
                                $logger->logdie("wrong message type for message $id: $type");
                            }
                        }
                    }
                },

                disconnect => sub {
                    my ( $conn, $code, $reason ) = @_;

                    my $environment = $conn->{environment};
                    my $username    = $conn->{username};
                    my $conn_id     = $conn->{connection_id};

                    delete $CONNECTIONS_BY_ENV{$environment}->{$username}->{$conn_id};

                    unless ( %{$CONNECTIONS_BY_ENV{$environment}->{$username}} ) {
                        delete $CONNECTIONS_BY_ENV{$environment}->{$username};
                    }

                    delete $CONNECTIONS_BY_ID{$conn_id};

                    $logger->info("user $username on $environment disconnected (code: $code - reason: $reason)");
                },
            );
        }
    )->start;
}

