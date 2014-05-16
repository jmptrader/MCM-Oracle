#!/usr/bin/perl -w

#
# sysperfstat - System Performance Statistics. Solaris 8+, Perl.
#
# This displays utilisation and saturation for CPU, memory, disk and network.
# This can be useful to get an overall view of system performance, the
# "view from 20,000 feet".
#
# 19-Mar-2006, ver 0.85
#
# USAGE:    sysperfstat [-h] | [interval [count]]
#    eg,
#           sysperfstat                 # print summary since boot only
#           sysperfstat 5               # print continually, every 5 seconds
#           sysperfstat 1 5             # print 5 times, every 1 second
#           sysperfstat -h              # print help
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
my $Kstat = Sun::Solaris::Kstat->new();

#
#  Tunables
#

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
my @Disk = qw(cmdk dad sd ssd);
#
#  Process command line args
#
usage() if defined $ARGV[0] and $ARGV[0] =~ /^(-h|--help|0)$/;

# process [interval [count]],
my ($interval, $loop_max);
if (defined $ARGV[0]) {
    $interval = $ARGV[0];
    $loop_max = defined $ARGV[1] ? $ARGV[1] : 2**32;
    usage() if $interval == 0;
}
else {
    $interval = 1;
    $loop_max = 1;
}

#
#  Variables
#
my $loop = 0;               # current loop number
my $PAGESIZE = 20;          # max lines per header
my $lines = $PAGESIZE;      # counter for lines printed
my $cycles  = 0;            # CPU ticks usr + sys
my $freepct = 0;            # Memory free
my $busy    = 0;            # Disk busy
my $thrput  = 0;            # Network r+w bytes
my $runque  = 0;            # CPU total run queue length
my $scan    = 0;            # Memory scan rate
my $wait    = 0;            # Disk wait sum
my $error   = 0;            # Network errors
$| = 1;
my ($update1, $update2, $update3, $update4);

### Set Disk and Network identify hashes
my (%Disk, %Network);
$Disk{$_} = 1 foreach (@Disk);
discover_net();


#
#  Main
#

while (1) {

    ### Print header
#    if ($lines++ >= $PAGESIZE) {
#        $lines = 0;
#        printf "%8s %28s %28s\n", "", "------ Utilisation ------",
#               "------ Saturation ------";
#        printf "%8s %7s %6s %6s %6s %7s %6s %6s %6s\n", "Time", "%CPU",
#               "%Mem", "%Disk", "%Net", "CPU", "Mem", "Disk", "Net";
#    }

    #
    #  Store old values
    #
    my $oldupdate1 = $update1;
    my $oldupdate2 = $update2;
    my $oldupdate3 = $update3;
    my $oldupdate4 = $update4;
    my $oldcycles  = $cycles;
    my $oldbusy    = $busy;
    my $oldthrput  = $thrput;
    my $oldrunque  = $runque;
    my $oldscan     = $scan;
    my $oldwait     = $wait;
    my $olderror    = $error;

    #
    #  Get new values
    #
    $Kstat->update();
    ($cycles, $runque, $update1) = fetch_cpu();
    ($freepct, $scan, $update2)  = fetch_mem();
    ($busy, $wait, $update3)     = fetch_disk();
    ($thrput, $error, $update4)  = fetch_net();

    #
    #  Calculate utilisation
    #
    my $ucpu  = ratio($cycles, $oldcycles, $update1, $oldupdate1, 100);
    my $umem  = sprintf("%.2f", $freepct);
    my $udisk = ratio($busy, $oldbusy, $update3, $oldupdate3);
    my $unet  = ratio($thrput, $oldthrput, $update4, $oldupdate4);

    #
    #  Calculate saturation
    #
    my $scpu  = ratio($runque, $oldrunque, $update1, $oldupdate1);
    my $smem  = ratio($scan, $oldscan, $update2, $oldupdate2);
    my $sdisk = ratio($wait, $oldwait, $update3, $oldupdate3);
    my $snet  = ratio($error, $olderror, $update4, $oldupdate4);

    #
    #  Print utilisation and saturation
    #
#    my @Time = localtime();
#    printf "%02d:%02d:%02d %7s %6s %6s %6s %7s %6s %6s %6s\n",
#           $Time[2], $Time[1], $Time[0], $ucpu, $umem, $udisk, $unet,
#           $scpu, $smem, $sdisk, $snet;
    printf "%d:%s:%s:%s:%s:%s:%s:%s:%s\n", time(), $ucpu, $umem, $udisk, $unet, $scpu, $smem, $sdisk, $snet;

    ### Check for end
    last if ++$loop == $loop_max;

    ### Interval
    sleep $interval;
}


#
#  Subroutines
#

# fetch_cpu - fetch current usr + sys times, and the runque length.
#
sub fetch_cpu {

    ### Variables
    my ($runqueue, $time, $usr, $sys, $util, $numcpus);
    $usr = 0; $sys = 0;

    ### Loop over all CPUs
    my $Modules = $Kstat->{cpu_stat};
    foreach my $instance (keys(%$Modules)) {
        my $Instances = $Modules->{$instance};

        foreach my $name (keys(%$Instances)) {
            ### Utilisation - usr + sys
            my $Names = $Instances->{$name};
            if (defined $$Names{user}) {
                $usr += $$Names{user};
                $sys += $$Names{kernel};
                # use last time seen
                $time = $$Names{snaptime};
            }
        }
    }

    ### Saturation - runqueue length
    $runqueue = $Kstat->{unix}->{0}->{sysinfo}->{runque};

    ### Utilisation - usr + sys
    $numcpus = $Kstat->{unix}->{0}->{system_misc}->{ncpus};
    $numcpus = 1 if $numcpus == 0;
    $util = ($usr + $sys) / $numcpus;
    $util = $util * 100/$HERTZ if $HERTZ != 100;

    ### Return
    return ($util, $runqueue, $time);
}

# fetch_mem - return memory percent utilised and scanrate.
#
# To determine the memory utilised, we use availrmem as the limit of
# usable RAM by the VM system, and freemem as the amount of RAM
# currently free.
#
sub fetch_mem {

    ### Variables
    my ($scan, $time, $pct, $freemem, $availrmem);
    $scan = 0;

    ### Loop over all CPUs
    my $Modules = $Kstat->{cpu_stat};
    foreach my $instance (keys(%$Modules)) {
        my $Instances = $Modules->{$instance};

        foreach my $name (keys(%$Instances)) {
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
    $availrmem = $Kstat->{unix}->{0}->{system_pages}->{availrmem};
    $freemem = $Kstat->{unix}->{0}->{system_pages}->{freemem};

    #
    # Process utilisation.
    # this is a little odd, most values from kstat are incremental
    # however these are absolute. we calculate and return the final
    # value as a percentage. page conversion is not necessary as
    # we divide that value away.
    #
    $pct = 100 - 100 * ($freemem / $availrmem);
    #
    # Process Saturation.
    # Divide scanrate by slowscan, to create sensible saturation values.
    # Eg, a consistant load of 1.00 indicates consistantly at slowscan.
    # slowscan is usually 100.
    #
    $scan = $scan / $Kstat->{unix}->{0}->{system_pages}->{slowscan};

    ### Return
    return ($pct, $scan, $time);
}

# fetch_disk - fetch kstat values for the disks.
#
# The values used are  the r+w times for utilisation, and wlentime
# for saturation.
#
sub fetch_disk {

    ### Variables
    my ($wait, $time, $rtime, $wtime, $disktime);
    $wait = $rtime = $wtime = 0;

    ### Loop over all Disks
    foreach my $module (keys(%$Kstat)) {

        # Check that this is a physical disk
        next unless $Disk{$module};
        my $Modules = $Kstat->{$module};

        foreach my $instance (keys(%$Modules)) {
            my $Instances = $Modules->{$instance};

            foreach my $name (keys(%$Instances)) {

                # Check that this isn't a slice
                next if $name =~ /,/;

                my $Names = $Instances->{$name};

                ### Utilisation - r+w times
                if (defined $$Names{rtime} or defined $$Names{rtime64}) {
                    # this is designed to be future safe
                    if (defined $$Names{rtime64}) {
                        $rtime += $$Names{rtime64};
                        $wtime += $$Names{wtime64};
                    }
                    else {
                        $rtime += $$Names{rtime};
                        $wtime += $$Names{wtime};
                    }
                }

                ### Saturation - wait queue
                if (defined $$Names{wlentime}) {
                    $wait += $$Names{wlentime};
                    $time = $$Names{snaptime};
                }
            }
        }
    }

    ### Process Utilisation
    $disktime = 100 * ($rtime + $wtime);
    ### Return
    return ($disktime, $wait, $time);
}

# fetch_net - fetch kstat values for the network interfaces.
#
# The values used are r+w bytes, defer, nocanput, norcvbuf and noxmtbuf.
# These error statistics aren't ideal, as they are not always triggered
# for network satruation. Future versions may pull this from the new tcp
# mib2 or net class kstats in Solaris 10.
#
sub fetch_net {

    ### Variables
    my ($err, $time, $speed, $util, $rbytes, $wbytes);
    $err = $util = 0;

    ### Loop over all NICs
    foreach my $module (keys(%$Kstat)) {

        # Check this is a network device
        next unless $Network{$module};
        my $Modules = $Kstat->{$module};

        foreach my $instance (keys(%$Modules)) {
            my $Instances = $Modules->{$instance};

            foreach my $name (keys(%$Instances)) {
                my $Names = $Instances->{$name};

                # Check that this is a network device
                next unless defined $$Names{ifspeed};

                ### Utilisation - r+w bytes
                if (defined $$Names{obytes} or defined $$Names{obytes64}) {
                    if (defined $$Names{obytes64}) {
                        $rbytes = $$Names{rbytes64};
                        $wbytes = $$Names{obytes64};
                    }
                    else {
                        $rbytes = $$Names{rbytes};
                        $wbytes = $$Names{obytes};
                    }

                    if (defined $$Names{ifspeed} and $$Names{ifspeed}) {
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
                if (defined $$Names{nocanput} or defined $$Names{norcvbuf}) {
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

    ### Return
    return ($util, $err, $time);
}

# discover_net - discover network modules, populate %Network.
#
# This could return an array of pointers to Kstat objects, but for
# now I've kept things simple.
#
sub discover_net {

    ### Loop over all NICs
    foreach my $module (keys(%$Kstat)) {

        my $Modules = $Kstat->{$module};
        foreach my $instance (keys(%$Modules)) {

            my $Instances = $Modules->{$instance};
            foreach my $name (keys(%$Instances)) {

                my $Names = $Instances->{$name};

                # Check this is a network device.
                # Matching on ifspeed has been more reliable than "class"
                if (defined $$Names{ifspeed}) {
                    $Network{$module} = 1;
                }
            }
        }
    }
}

# ratio - calculate the ratio of a count delta over time delta.
#
# Takes count and oldcount, time and oldtime. Returns a string
# of the value, or a null string if not enough data was provided.
#
sub ratio {

    my ($count, $oldcount, $time, $oldtime, $max) = @_;

    # Calculate deltas
    my $countd = $count - (defined $oldcount ? $oldcount : 0);
    my $timed = $time - (defined $oldtime ? $oldtime : 0);

    # Calculate ratio
    my $ratio = $timed > 0 ? $countd / $timed : 0;

    # Maximum cap
    if (defined $max) {
        $ratio = $max if $ratio > $max;
    }
    # Return as rounded string
    return sprintf "%.2f", $ratio;
}

# usage - print usage and exit.
#
sub usage {
        print STDERR <<END;
USAGE: sysperfstat [-h] | [interval [count]]
   eg, sysperfstat               # print summary since boot only
       sysperfstat 5             # print continually every 5 seconds
       sysperfstat 1 5           # print 5 times, every 1 second
END
        exit 1;
}
