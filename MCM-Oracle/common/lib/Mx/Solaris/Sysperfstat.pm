package Mx::Solaris::Sysperfstat;

#
# sysperfstat - System Performance Statistics. Solaris 8+, Perl.
#
# This displays utilisation and saturation for CPU, memory, disk and network.
# This can be useful to get an overall view of system performance, the
# "view from 20,000 feet".
#
# 19-Mar-2006, ver 0.85
#
# This program prints utilisation and saturation values from four areas
# on one line. The first line printed is the summary since boot.
# The values represent,
#
# Utilisation,
#           CPU            # usr + sys time across all CPUs
#           Memory         # free RAM. freemem from availrmem
#           Disk           # %busy. r+w times across all Disks
#           Network        # throughput. r+w bytes across all NICs
#
# Saturation,
#           CPU            # threads on the run queue
#           Memory         # scan rate of the page scanner
#           Disk           # operations on the wait queue
#           Network        # errors due to buffer saturation
#
# The utilisation values for CPU and Memory have maximum values of 100%,
# Disk and Network don't. 100% CPU means all CPUs are running at 100%, however
# 100% Disk means perhaps 1 disk is running at 100%, or 2 disks at 50%;
# a similar calculation is used for Network. There are some sensible
# reasons behind this decision that I hope to document at some point.
#
# The saturation values have been tuned to be similar to system load averages;
# A value of 1.00 indicates moderate saturation of the resource (usually bad),
# a value of 4.00 would indicate heavy saturation or demand for the resource.
# A value of 0.00 does not indicate idle or unused - rather not saturated.
#
# See other Solaris commands for further details on utilisation or saturation.
#
# NOTE: For new physical disk types, add their module name to the @Disk
# tunable in the code below.
#
# Author: Brendan Gregg  [Sydney, Australia]
#

use strict;
use Sun::Solaris::Kstat;
use Solaris::loadavg;
use Carp;

#
# Default tick rate. use 1000 if hires_tick is on
#
my $HERTZ = 100;

#
# Default NIC speed (if detection fails). 100 Mbits/sec
#
my $NIC_SPEED = 100_000_000;

#
# Disk module names
# these are deliberatly hard-coded, so that we match physical
# disks and not metadevices (which from kstat look like disks).
# matching metadevices would overcount disk statistics.
#
my %dsk_modules = (
  cmdk => 1,
  dad  => 1,
  sd   => 1,
  ssd  => 1,
);

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    $self->{kstat} = Sun::Solaris::Kstat->new();

    $self->{cycles}    = 0;            # CPU ticks usr + sys
    $self->{runque}    = 0;            # CPU total run queue length
    $self->{freepct}   = 0;            # Memory free
    $self->{scan}      = 0;            # Memory scan rate
    $self->{busy}      = 0;            # Disk busy
    $self->{wait}      = 0;            # Disk wait sum
    $self->{thrput}    = 0;            # Network r+w bytes
    $self->{error}     = 0;            # Network errors

    $self->{update1}   = undef;
    $self->{update2}   = undef;
    $self->{update3}   = undef;
    $self->{update4}   = undef;

    $self->{timestamp} = undef;

    my %net_modules = discover_net( $self->{kstat} );

    my @dsk_modules = (); my @net_modules = ();
    foreach my $module ( keys( %{$self->{kstat}} ) ) {
        push @dsk_modules, $module if $dsk_modules{$module};
        push @net_modules, $module if $net_modules{$module};
    }

    $self->{dsk_modules} = \@dsk_modules;
    $self->{net_modules} = \@net_modules;

    $logger->info("detected disk modules: @dsk_modules");
    $logger->info("detected network modules: @net_modules");

    bless $self, $class;
}

#-----------#
sub refresh { 
#-----------#
    my ( $self ) = @_;


    #
    #  Store old values
    #
    my $oldcycles  = $self->{cycles};
    my $oldrunque  = $self->{runque};
    my $oldscan    = $self->{scan};
    my $oldbusy    = $self->{busy};
    my $oldwait    = $self->{wait};
    my $oldthrput  = $self->{thrput};
    my $olderror   = $self->{error};
    my $oldupdate1 = $self->{update1};
    my $oldupdate2 = $self->{update2};
    my $oldupdate3 = $self->{update3};
    my $oldupdate4 = $self->{update4};

    #
    #  Get new values
    #
    $self->{kstat}->update();
    $self->{timestamp} = time();

    ( $self->{cycles},  $self->{runque}, $self->{update1} ) = fetch_cpu( $self->{kstat} );
    ( $self->{freepct}, $self->{scan},   $self->{update2} ) = fetch_mem( $self->{kstat} );
    ( $self->{busy},    $self->{wait},   $self->{update3} ) = fetch_dsk( $self->{kstat}, $self->{dsk_modules} );
    ( $self->{thrput},  $self->{error},  $self->{update4} ) = fetch_net( $self->{kstat}, $self->{net_modules} );

    #
    #  Calculate utilisation
    #
    $self->{ucpu} = ratio( $self->{cycles}, $oldcycles, $self->{update1}, $oldupdate1, 100 );
    $self->{umem} = sprintf("%.2f", $self->{freepct} );
    $self->{udsk} = ratio( $self->{busy}, $oldbusy, $self->{update3}, $oldupdate3 );
    $self->{unet} = ratio( $self->{thrput}, $oldthrput, $self->{update4}, $oldupdate4 );

    #
    #  Calculate saturation
    #
    $self->{scpu} = ratio( $self->{runque}, $oldrunque, $self->{update1}, $oldupdate1 );
    $self->{smem} = ratio( $self->{scan}, $oldscan, $self->{update2}, $oldupdate2 );
    $self->{sdsk} = ratio( $self->{wait}, $oldwait, $self->{update3}, $oldupdate3 );
    $self->{snet} = ratio( $self->{error}, $olderror, $self->{update4}, $oldupdate4 );

    $self->{load} = sprintf("%.2f", (loadavg(1))[0]);

    return 1;
}

#
# fetch_cpu - fetch current usr + sys times, and the runque length.
#
#-------------#
sub fetch_cpu {
#-------------#
    my ( $kstat ) = @_;


    my $usr = 0; my $sys = 0; my $time;

    ### Loop over all CPUs
    my $Modules = $kstat->{cpu_stat};
    foreach my $instance ( keys( %{$Modules} ) ) {
        my $Instances = $Modules->{$instance};

        foreach my $name ( keys( %{$Instances} ) ) {
            ### Utilisation - usr + sys
            my $Names = $Instances->{$name};
            if ( defined $$Names{user} ) {
                $usr += $$Names{user};
                $sys += $$Names{kernel};
                # use last time seen
                $time = $$Names{snaptime};
            }
        }
    }

    ### Saturation - runqueue length
    my $runqueue = $kstat->{unix}->{0}->{sysinfo}->{runque};

    ### Utilisation - usr + sys
    my $numcpus = $kstat->{unix}->{0}->{system_misc}->{ncpus};
    $numcpus = 1 if $numcpus == 0;
    my $util = ($usr + $sys) / $numcpus;
    $util = $util * 100/$HERTZ if $HERTZ != 100;

    return ($util, $runqueue, $time);
}

# fetch_mem - return memory percent utilised and scanrate.
#
# To determine the memory utilised, we use availrmem as the limit of
# usable RAM by the VM system, and freemem as the amount of RAM
# currently free.
#
#-------------#
sub fetch_mem {
#-------------#
    my ( $kstat ) = @_;


    my $scan = 0; my $time;

    ### Loop over all CPUs
    my $Modules = $kstat->{cpu_stat};
    foreach my $instance ( keys( %{$Modules} ) ) {
        my $Instances = $Modules->{$instance};

        foreach my $name ( keys( %{$Instances} ) ) {
            my $Names = $Instances->{$name};

            ### Saturation - scan rate
            if (defined $$Names{scan}) {
                $scan += $$Names{scan};
                # use last time seen
                $time = $$Names{snaptime};
            }
        }
    }

    ### Utilisation - free RAM (freemem from availrmem)
    my $availrmem = $kstat->{unix}->{0}->{system_pages}->{availrmem};
    my $freemem   = $kstat->{unix}->{0}->{system_pages}->{freemem};

    #
    # Process utilisation.
    # this is a little odd, most values from kstat are incremental
    # however these are absolute. we calculate and return the final
    # value as a percentage. page conversion is not necessary as
    # we divide that value away.
    #
    my $pct = 100 - 100 * ($freemem / $availrmem);

    #
    # Process Saturation.
    # Divide scanrate by slowscan, to create sensible saturation values.
    # Eg, a consistant load of 1.00 indicates consistantly at slowscan.
    # slowscan is usually 100.
    #
    $scan = $scan / $kstat->{unix}->{0}->{system_pages}->{slowscan};

    return ($pct, $scan, $time);
}

# fetch_dsk - fetch kstat values for the disks.
#
# The values used are  the r+w times for utilisation, and wlentime
# for saturation.
#
#-------------#
sub fetch_dsk {
#-------------#
    my ( $kstat, $dsk_modules ) = @_;


    my $wait = 0; my $rtime = 0; my $wtime = 0; my $time;

    ### Loop over all Disks
    foreach my $module ( @{$dsk_modules} ) {
        my $Modules = $kstat->{$module};

        foreach my $instance ( keys( %{$Modules} ) ) {
            my $Instances = $Modules->{$instance};

            foreach my $name ( keys( %{$Instances} ) ) {
                # Check that this isn't a slice
                next if $name =~ /,/;

                my $Names = $Instances->{$name};

                ### Utilisation - r+w times
                if ( defined $$Names{rtime} or defined $$Names{rtime64} ) {
                    # this is designed to be future safe
                    if ( defined $$Names{rtime64} ) {
                        $rtime += $$Names{rtime64};
                        $wtime += $$Names{wtime64};
                    }
                    else {
                        $rtime += $$Names{rtime};
                        $wtime += $$Names{wtime};
                    }
                }

                ### Saturation - wait queue
                if ( defined $$Names{wlentime} ) {
                    $wait += $$Names{wlentime};
                    $time = $$Names{snaptime};
                }
            }
        }
    }

    ### Process Utilisation
    my $disktime = 100 * ($rtime + $wtime);

    return ($disktime, $wait, $time);
}

# fetch_net - fetch kstat values for the network interfaces.
#
# The values used are r+w bytes, defer, nocanput, norcvbuf and noxmtbuf.
# These error statistics aren't ideal, as they are not always triggered
# for network satruation. Future versions may pull this from the new tcp
# mib2 or net class kstats in Solaris 10.
#
#-------------#
sub fetch_net {
#-------------#
    my ( $kstat, $net_modules ) = @_;


    my $err = 0; my $util = 0; my $time; 

    ### Loop over all NICs
    foreach my $module ( @{$net_modules} ) {
        my $Modules = $kstat->{$module};

        foreach my $instance ( keys( %{$Modules} ) ) {
            my $Instances = $Modules->{$instance};

            foreach my $name ( keys( %{$Instances} ) ) {
                my $Names = $Instances->{$name};

                # Check that this is a network device
                next unless defined $$Names{ifspeed};

                ### Utilisation - r+w bytes
                if ( defined $$Names{obytes} or defined $$Names{obytes64} ) {
                    my $rbytes; my $wbytes;
                    if ( defined $$Names{obytes64} ) {
                        $rbytes = $$Names{rbytes64};
                        $wbytes = $$Names{obytes64};
                    }
                    else {
                        $rbytes = $$Names{rbytes};
                        $wbytes = $$Names{obytes};
                    }

                    my $speed;
                    if ( defined $$Names{ifspeed} and $$Names{ifspeed} ) {
                        $speed = $$Names{ifspeed};
                    }
                    else {
                        $speed = $NIC_SPEED;
                    }

                    #
                    # Process Utilisation.
                    # the following has a mysterious "800", it is 100
                    # for the % conversion, and 8 for bytes2bits.
                    # $util is cumulative, and needs further processing.
                    #
                    $util += 800 * ($rbytes + $wbytes) / $speed;
                }

                ### Saturation - errors
                if ( defined $$Names{nocanput} or defined $$Names{norcvbuf} ) {
                    $err += defined $$Names{defer} ? $$Names{defer} : 0;
                    $err += defined $$Names{nocanput} ? $$Names{nocanput} : 0;
                    $err += defined $$Names{norcvbuf} ? $$Names{norcvbuf} : 0;
                    $err += defined $$Names{noxmtbuf} ? $$Names{noxmtbuf} : 0;
                    $time = $$Names{snaptime};
                }
            }
        }
    }

    #
    # Process Saturation.
    # Divide errors by 200. This gives more sensible load averages,
    # such as 4.00 meaning heavily saturated rather than 800.00.
    #
    $err = $err / 200;

    return ($util, $err, $time);
}

# discover_net - discover network modules, populate %Network.
#
# This could return an array of pointers to Kstat objects, but for
# now I've kept things simple.
#
#----------------#
sub discover_net {
#----------------#
    my ( $kstat ) = @_;


    my %modules = ();

    ### Loop over all NICs
    foreach my $module ( keys( %{$kstat} ) ) {
        my $Modules = $kstat->{$module};

        foreach my $instance ( keys( %{$Modules} ) ) {
            my $Instances = $Modules->{$instance};

            foreach my $name ( keys( %{$Instances} ) ) {
                my $Names = $Instances->{$name};

                # Check this is a network device.
                # Matching on ifspeed has been more reliable than "class"
                if ( defined $$Names{ifspeed} ) {
                    $modules{$module} = 1;
                }
            }
        }
    }

    return %modules;
}

# ratio - calculate the ratio of a count delta over time delta.
#
# Takes count and oldcount, time and oldtime. Returns a string
# of the value, or a null string if not enough data was provided.
#
#---------#
sub ratio {
#---------#
    my ($count, $oldcount, $time, $oldtime, $max) = @_;


    # Calculate deltas
    my $countd = $count - (defined $oldcount ? $oldcount : 0);
    my $timed  = $time - (defined $oldtime ? $oldtime : 0);

    # Calculate ratio
    my $ratio = $timed > 0 ? $countd / $timed : 0;

    # Maximum cap
    if (defined $max) {
        $ratio = $max if $ratio > $max;
    }

    # Return as rounded string
    return sprintf "%.2f", $ratio;
}

#-------------#
sub timestamp {
#-------------#
    my ( $self ) = @_;

    return $self->{timestamp};
}

#--------#
sub ucpu {
#--------#
    my ( $self ) = @_;

    return $self->{ucpu};
}

#--------#
sub umem {
#--------#
    my ( $self ) = @_;

    return $self->{umem};
}

#--------#
sub udsk {
#--------#
    my ( $self ) = @_;

    return $self->{udsk};
}

#--------#
sub unet {
#--------#
    my ( $self ) = @_;

    return ( $self->{unet} < 0 ) ? 0 : $self->{unet};
}

#--------#
sub scpu {
#--------#
    my ( $self ) = @_;

    return $self->{scpu};
}

#--------#
sub smem {
#--------#
    my ( $self ) = @_;

    return $self->{smem};
}

#--------#
sub sdsk {
#--------#
    my ( $self ) = @_;

    return $self->{sdsk};
}

#--------#
sub snet {
#--------#
    my ( $self ) = @_;

    return $self->{snet};
}

#--------#
sub load {
#--------#
    my ( $self ) = @_;

    return $self->{load};
}

1;
