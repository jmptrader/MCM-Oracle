#!/usr/bin/env perl

use Mx::Log;
use Mx::Config;
use Mx::MDML;
use Data::Dumper;

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mdml'); 

my $file = '/shared/.tmp/fo_BR_FXO_U24453_fxvl+fxsm_20120502_085858_20120502090017.xml';
#my $file = '/shared/.tmp/fo_BR_FXO_U24453_fxvl+fxsm_20120502_085424_20120502085516.xml';

my $mdml = Mx::MDML->new( filename => $file, logger => $logger );

$mdml->mds;
$mdml->date;
$mdml->types;

my @pairs = $mdml->vol_pairs;

my ( $pair ) = @pairs;

my @matrix = $mdml->vol_matrix( pair => $pair );

$mdml->mail_address;

print Dumper( @matrix );
