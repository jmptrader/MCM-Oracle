#!/usr/bin/env perl

use XML::Simple;

#my $file = '/shared/.tmp/fo_BR_FXO_U24453_fxvl+fxsm_20120502_085858_20120502090017.xml';
my $file = '/shared/.tmp/fo_BR_FXO_U24453_fxvl+fxsm_20120502_085424_20120502085516.xml';

my $xs = XML::Simple->new();

my $ref = $xs->XMLin( $file );

my $action = $ref->{'xc:action'};

print "action: $action\n";

my $mds = $ref->{'xc:XmlCacheArea'}->{'mp:nickName'}->{'xc:value'};

print "mds: $mds\n";

my $date = $ref->{'xc:XmlCacheArea'}->{'mp:nickName'}->{'mp:date'}->{'xc:value'};

print "date: $date\n";
