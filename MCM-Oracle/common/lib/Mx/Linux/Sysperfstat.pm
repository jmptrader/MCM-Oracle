package Mx::Linux::Sysperfstat;

use strict;
use warnings;

use Time::HiRes qw( time );
use POSIX;
use Carp;
use Mx::System;
use Mx::Log;


my $HERTZ   = POSIX::sysconf( &POSIX::_SC_CLK_TCK );
my $NR_CPUS = 1;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Linux system performance object (config)");
    }

    my $system = Mx::System->new( config => $config, logger => $logger );

    $NR_CPUS = $system->nr_cpus();

    $self->{cycles_user}   = 0;
    $self->{cycles_system} = 0;
    $self->{cycles_idle}   = 0;
    $self->{cycles_iowait} = 0;

    $self->{memfreepct}    = 0;
    $self->{swapfreepct}   = 0;

    $self->{sec_read}      = 0; 
    $self->{sec_write}     = 0;

    $self->{kbit_rx}       = 0;
    $self->{kbit_tx}       = 0;

    $self->{load}          = 0;

    $self->{update1}       = undef;
    $self->{update2}       = undef;
    $self->{update3}       = undef;
    $self->{update4}       = undef;

    $self->{timestamp} = undef;

    bless $self, $class;
}

#-----------#
sub refresh {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    #
    # Store old values
    #
    my $oldcycles_user   = $self->{cycles_user};
    my $oldcycles_system = $self->{cycles_system};
    my $oldcycles_idle   = $self->{cycles_idle};
    my $oldcycles_iowait = $self->{cycles_iowait};

    my $oldsec_read      = $self->{sec_read};
    my $oldsec_write     = $self->{sec_write};

    my $oldkbit_rx       = $self->{kbit_rx};
    my $oldkbit_tx       = $self->{kbit_tx};

    my $oldupdate1       = $self->{update1};
    my $oldupdate2       = $self->{update2};
    my $oldupdate3       = $self->{update3};
    my $oldupdate4       = $self->{update4};

    #
    #  Get new values
    #
    $self->{timestamp} = int(time()); 

    ( $self->{cycles_user}, $self->{cycles_system}, $self->{cycles_idle}, $self->{cycles_iowait}, $self->{update1} ) = fetch_cpu( $logger );
    ( $self->{memfreepct}, $self->{swapfreepct}, $self->{update2} ) = fetch_mem( $logger );
    ( $self->{sec_read}, $self->{sec_write}, $self->{update3} ) = fetch_dsk( $logger );
    ( $self->{kbit_rx}, $self->{kbit_tx}, $self->{update4} ) = fetch_net( $logger );
    $self->{load} = fetch_load( $logger );

    #
    # Calculate utilisation
    #
    $self->{ucpu_user}   = ratio( $self->{cycles_user},   $oldcycles_user,   $self->{update1}, $oldupdate1, 1, 100 );
    $self->{ucpu_system} = ratio( $self->{cycles_system}, $oldcycles_system, $self->{update1}, $oldupdate1, 1, 100 );
    $self->{ucpu_idle}   = ratio( $self->{cycles_idle},   $oldcycles_idle,   $self->{update1}, $oldupdate1, 1, 100 );
    $self->{ucpu_iowait} = ratio( $self->{cycles_iowait}, $oldcycles_iowait, $self->{update1}, $oldupdate1, 1, 100 );

    $self->{umem}        = sprintf("%.2f", $self->{memfreepct} );
    $self->{uswap}       = sprintf("%.2f", $self->{swapfreepct} );

    $self->{udsk_read}   = ratio( $self->{sec_read},  $oldsec_read,  $self->{update3}, $oldupdate3, 1 );
    $self->{udsk_write}  = ratio( $self->{sec_write}, $oldsec_write, $self->{update3}, $oldupdate3, 1 );

    $self->{unet_rx}     = ratio( $self->{kbit_rx}, $oldkbit_rx, $self->{update4}, $oldupdate4, 0 );
    $self->{unet_tx}     = ratio( $self->{kbit_tx}, $oldkbit_tx, $self->{update4}, $oldupdate4, 0 );

    $self->{load}        = sprintf("%.2f", $self->{load} );
}

#-------------#
sub fetch_cpu {
#-------------#
    my ( $logger ) = @_;


    unless ( open FH, '/proc/stat' ) {
        $logger->logdie("cannot open /proc/stat: $!");
    }

    my $line = <FH>;

    close(FH);

    my $factor = 1 / $HERTZ / $NR_CPUS;

    if ( $line =~ /^cpu\s+(\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/ ) {
        my $cycles_user   = ( $1 + $2 ) * $factor;
        my $cycles_system = ( $3 + $6 + $7 ) * $factor;
        my $cycles_idle   = $4 * $factor;
        my $cycles_iowait = $5 * $factor;

        return( $cycles_user, $cycles_system, $cycles_idle, $cycles_iowait, time() );
    }
}

#-------------#
sub fetch_mem {
#-------------#
    my ( $logger ) = @_;


    unless ( open FH, '/proc/meminfo' ) {
        $logger->logdie("cannot open /proc/meminfo: $!");
    }

    my ( $memtotal, $memfree, $swaptotal, $swapfree );
    while ( my $line = <FH> ) {
        if ( $line =~ /^MemTotal:\s+(\d+) kB/ ) {
            $memtotal = $1;
        }
        elsif ( $line =~ /^MemFree:\s+(\d+) kB/ ) {
            $memfree = $1;
        }
        elsif ( $line =~ /^SwapTotal:\s+(\d+) kB/ ) {
            $swaptotal = $1;
        }
        elsif ( $line =~ /^SwapFree:\s+(\d+) kB/ ) {
            $swapfree = $1;
        }
    }

    close(FH);

    my $memfreepct  = $memfree / $memtotal * 100 if $memtotal;
    my $swapfreepct = $swapfree / $swaptotal * 100 if $swaptotal;

    return ( $memfreepct, $swapfreepct, time() );
}

#-------------#
sub fetch_dsk {
#-------------#
    my ( $logger ) = @_;


    unless ( open FH, '/proc/diskstats' ) {
        $logger->logdie("cannot open /proc/diskstats: $!");
    }

    my ( $ms_read, $ms_write );
    while ( my $line = <FH> ) {
        if ( $line =~ /^\s*\d+\s+\d+ sd[a-z] \d+ \d+ \d+ (\d+) \d+ \d+ \d+ (\d+) / ) {
            $ms_read  += $1;
            $ms_write += $2;
        }
    }

    close(FH);

    return ( $ms_read / 1000, $ms_write / 1000, time() );
}

#-------------#
sub fetch_net {
#-------------#
    my ( $logger ) = @_;


    unless ( open FH, '/proc/net/dev' ) {
        $logger->logdie("cannot open /proc/net/dev: $!");
    }

    my ( $bytes_rx, $bytes_tx );
    while ( my $line = <FH> ) {
        if ( $line =~ /^\s*eth[0-9]:(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+/ ) {
            $bytes_rx += $1;
            $bytes_tx += $2;
        }
    }

    close(FH);

    my $kbit_rx = $bytes_rx * 8 / 1024;
    my $kbit_tx = $bytes_tx * 8 / 1024;

    return ( $kbit_rx, $kbit_tx, time() );
}

#--------------#
sub fetch_load {
#--------------#
    my ( $logger ) = @_;


    unless ( open FH, '/proc/loadavg' ) {
        $logger->logdie("cannot open /proc/loadavg: $!");
    }

    my $line = <FH>;

    close(FH);

    if ( $line =~ /^(\d+\.\d+)\s+/ ) {
        return $1;
    }
}

# ratio - calculate the ratio of a count delta over time delta.
#
# Takes count and oldcount, time and oldtime. Returns a string
# of the value, or a null string if not enough data was provided.
#
#---------#
sub ratio {
#---------#
    my ($count, $oldcount, $time, $oldtime, $percentage, $max) = @_;


    # Calculate deltas
    my $countd = $count - ( defined $oldcount ? $oldcount : 0 );
    my $timed  = $time -  ( defined $oldtime ? $oldtime : 0 );

    # Calculate ratio
    my $ratio = $timed > 0 ? $countd / $timed : 0;

    $ratio *= 100 if $percentage;

    # Maximum cap
    if ( defined $max ) {
        $ratio = $max if $ratio > $max;
    }

    # Return as rounded string
    return sprintf "%.2f", $ratio;
}

#-------------#
sub ucpu_user {
#-------------#
    my ( $self ) = @_;

    return $self->{ucpu_user};
}

#---------------#
sub ucpu_system {
#---------------#
    my ( $self ) = @_;

    return $self->{ucpu_system};
}

#-------------#
sub ucpu_idle {
#-------------#
    my ( $self ) = @_;

    return $self->{ucpu_idle};
}

#---------------#
sub ucpu_iowait {
#---------------#
    my ( $self ) = @_;

    return $self->{ucpu_iowait};
}

#--------#
sub umem {
#--------#
    my ( $self ) = @_;

    return $self->{umem};
}

#---------#
sub uswap {
#---------#
    my ( $self ) = @_;

    return $self->{uswap};
}

#-------------#
sub udsk_read {
#-------------#
    my ( $self ) = @_;

    return $self->{udsk_read};
}

#--------------#
sub udsk_write {
#--------------#
    my ( $self ) = @_;

    return $self->{udsk_write};
}

#-----------#
sub unet_rx {
#-----------#
    my ( $self ) = @_;

    return $self->{unet_rx};
}

#-----------#
sub unet_tx {
#-----------#
    my ( $self ) = @_;

    return $self->{unet_tx};
}

#--------#
sub load {
#--------#
    my ( $self ) = @_;

    return $self->{load};
}

#-------------#
sub timestamp {
#-------------#
    my ( $self ) = @_;

    return $self->{timestamp};
}

1;
