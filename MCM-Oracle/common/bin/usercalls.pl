#!/usr/bin/env perl

use strict;
use IO::File;

my $TRESHOLD = 1;

my $pid  = $ARGV[0]; 
my $file = $ARGV[1];

my %calls = ();
my $total = 0;

my $dtrace = <<END;
/usr/sbin/dtrace -n '
	#pragma D option quiet
	profile:::profile-1001hz
	/pid == \$target/ 
	{
		\@pc[arg1] = count();
	}
	dtrace:::END
	{
		printa("OUT: %A %\@d\\n", \@pc);
	}
' '-p $pid'
END

open DTRACE, "$dtrace |" or die "cannot run dtrace (perms?): $!\n";

while (my $line = <DTRACE>) {
    next if $line =~ /^\s*$/;
    next if $line !~ /^OUT: /;
    my ($tag, $addr, $count) = split ' ', $line;
    my ($name, $offset) = split /\+/, $addr;
    next if $name eq "0x0";
    $calls{$name} += $count;
    $total += $count;
}

close DTRACE;

my $fh = IO::File->new("> $file") or die "cannot open $file: $!\n";

while ( my ($name, $count) = each %calls ) {
    my $percentage = $count / $total * 100;
    next unless $percentage >= $TRESHOLD;
    my ($library, $function) = split '`', $name;
    printf $fh "%s:%s:%.2f\n", $library, $function, $percentage;
}

$fh->close();

