package Mx::Network;

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Carp;

my $PING_COMMAND = '/usr/sbin/ping -s';

our $DEFAULT_PING_COUNT = 5;
our $DEFAULT_PING_SIZE  = 56;  

#--------#
sub ping {
#--------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $ip;
    unless ( $ip = $args{ip} ) {
        $logger->logdie("missing argument (ip)");
    }

    my $count = $args{count} || $DEFAULT_PING_COUNT;
    if ( $count < 1 or $count > 60 ) {
        $logger->logdie("count must be a number between 1 and 60");
    }

    my $size = $args{size} || $DEFAULT_PING_SIZE;
    if ( $size < 8 or $count > 65507 ) {
        $logger->logdie("count must be a number between 8 and 65507");
    }

    my $command = "$PING_COMMAND $ip $size $count";

    unless ( open CMD, "$command|" ) {
        $logger->error("cannot execute network ping ($command): $!");
        return;
    }

    my $received = 0; my $avg_time = 0;
    while ( my $line = <CMD> ) {
        if ( $line =~ /^\d+ packets transmitted, (\d+) packets received,/ ) {
            $received = $1;
            next;
        }
        if ( $line =~ /^round-trip \(ms\)  min\/avg\/max\/stddev = [\d.]+\/([\d.]+)\// ) {
            $avg_time = $1; 
        }
    }

    close(CMD);

    my $rate = $received / $count;
    $rate = sprintf "%.2f", $rate;

    return ( $rate, $avg_time );
}

1;
