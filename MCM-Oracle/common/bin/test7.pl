#!/usr/bin/env perl

use XML::XPath;
use Data::Dumper;
use Mx::Util;

my $file = $ARGV[0];

my $xml;
open FH, $file;
while ( <FH> ) {
    $xml .= $_;
}
close( FH );

my $xp = XML::XPath->new( xml => $xml );

#
# STATUS
#

my $status_set = $xp->find('/GuiRoot/Script/Status');

my $status = '';
if ( $status_set->size() == 1 ) {
    $status = $status_set->get_node(1)->string_value;
}

my $ok = ( $status eq 'Ended_Successfully' ) ? 1 : 0;

my $failure_type;
if ( $status eq 'Service_Failure' ) {
    $failure_type = 'service_failure';
}

#
# ERRORS
#

my @errors;

my $error_set = $xp->find('/GuiRoot/Script/ErrorsList/Errors/Error');

foreach my $error ( $error_set->get_nodelist ) {
    my $prefix; my $suffix;
    foreach my $child ( $error->getChildNodes ) {
        if ( $child->getName() eq 'Prefix' ) {
            $prefix = $child->string_value;
        }
        elsif ( $child->getName() eq 'Suffix' ) {
            $suffix = $child->string_value;
        }
    }

    if ( $prefix eq 'Overflow' ) {
        $failure_type = 'dyntable_overflow';
    }

    push @errors, { prefix => $prefix, suffix => $suffix };

    print "MX ANSWER: $suffix\n";
}

#
# WARNINGS
#

my @warnings; my $starttime;

my $warning_set = $xp->find('/GuiRoot/Script/ErrorsList/Warnings/Warning');

foreach my $warning ( $warning_set->get_nodelist ) {
    my $prefix; my $suffix;
    foreach my $child ( $warning->getChildNodes ) {
        if ( $child->getName() eq 'Prefix' ) {
            $prefix = $child->string_value;
        }
        elsif ( $child->getName() eq 'Suffix' ) {
            $suffix = $child->string_value;
        }
    }

    if ( $prefix eq 'Script started at' ) {
        $starttime = Mx::Util->proctime_to_epoch( $suffix );
    }

    push @warnings, { prefix => $prefix, suffix => $suffix };
}

#
# TIMING
#

my ( $runtime, $cputime, $iotime );

my $timing_set = $xp->find('/GuiRoot/Script/Timing');

if ( $timing_set->size() == 1 ) {
    my $timing = $timing_set->get_node(1);

    foreach my $child ( $timing->getChildNodes ) {
        if ( $child->getName() eq 'ElapsedTime' ) {
            $runtime = Mx::Util->convert_seconds_inv( $child->string_value );
        }
        elsif ( $child->getName() eq 'CPUTime' ) {
            $cputime = Mx::Util->convert_seconds_inv( $child->string_value );
        }
        elsif ( $child->getName() eq 'IOTime' ) {
            $iotime = Mx::Util->convert_seconds_inv( $child->string_value );
        }
    }
}

print Dumper( @errors );
print Dumper( @warnings );
print "starttime: $starttime\n";
print "runtime:   $runtime\n";
print "cputime:   $cputime\n";
print "iotime:    $iotime\n";
