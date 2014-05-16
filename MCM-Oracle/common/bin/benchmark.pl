#!/usr/bin/perl

use warnings;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);
use Getopt::Long;

my $TOTAL_WORKERS = 0;
my $CURRENT_OPS   = 0; 
my $TOTAL_OPS     = 0;
my $TOTAL_PROCS   = 0;
my $FORK_TIME     = 0;
my $MAX_FORK_TIME = 0;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: benchmark.pl [ -p <parallel> ] [ -t <runtime> ] [ -c <count> ]  [ -help ]

 -p <parallel>       Number of worker processes to run in parallel.
 -t <runtime>        Total runtime in seconds.
 -c <count>          Maximum number of operations per worker process.
 -help               Display this text.

EOT
;
    exit;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($parallel, $runtime, $count);

GetOptions(
    'p=s'     => \$parallel,
    't=s'     => \$runtime,
    'c=s'     => \$count,
    'help'    => \&usage,
);

#-----------------#
sub launch_worker {
#-----------------#
    my ( $routine, $count ) = @_;


    my $pid;
    my $t0 = [ gettimeofday ];
    if ( $pid = fork() ) {
        my $elapsed = tv_interval( $t0, [ gettimeofday ] );
        $FORK_TIME += $elapsed;
        $MAX_FORK_TIME = $elapsed if $elapsed > $MAX_FORK_TIME;
        $TOTAL_PROCS++;
        return $pid;
    }
    elsif ( defined $pid ) {
        for ( my $i = 0; $i < $count; $i++ ) {
            &{$routine}();
            $CURRENT_OPS++;
        }
        report();
    }
    else {
        die "cannot fork: $!";
    }
}

#-------------#
sub operation {
#-------------#
    my $result = 1/0.0000034;
}

#----------#
sub report {
#----------#
    open FH, ">/tmp/$$.ops";
    print FH "$CURRENT_OPS";
    close(FH);
    exit 0;
}

#----------#
sub reaper {
#----------#
    while ( ( my $pid = waitpid(-1, 0) ) > 0 ) {
        $TOTAL_WORKERS--;
        open FH, "</tmp/$pid.ops";
        my $count = <FH>;
        close(FH);
        unlink("/tmp/$pid.ops");
        $TOTAL_OPS += $count;
        $SIG{CHLD} = \&reaper;
    }
}

#----------------------#
sub separate_thousands {
#----------------------#
    my ( $number ) = @_;

    return undef unless defined $number;
    $number = reverse $number;
    $number =~ s/(\d{3})/$1,/g;
    $number = reverse $number;
    $number =~ s/^\,//;
    return $number;
}

$SIG{TERM} = \&report;
$SIG{CHLD} = \&reaper;

my $deadline = time() + $runtime;

while( time() < $deadline ) {
    while ( $TOTAL_WORKERS < $parallel ) {
        my $pid = launch_worker( \&operation, $count );
        $TOTAL_WORKERS++;
    }
}

printf "TOTAL OPERATIONS: %s\n", separate_thousands( $TOTAL_OPS );
printf "TOTAL PROCESSES: %s\n", separate_thousands( $TOTAL_PROCS );
printf "FORK OVERHEAD: %s\n", $FORK_TIME;
printf "MAX FORK TIME: %s\n", $MAX_FORK_TIME;
