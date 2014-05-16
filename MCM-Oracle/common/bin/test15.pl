#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Config;
use Mx::Log;
use Mx::Webservice::GTR;

use Data::Dumper;

my $config = Mx::Config->new();

my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'webservice' );

my $url = 'https://formacion.regis-tr.com:8082/regis_tr_xml_load/services/regis_tr_xml_load';

my $webservice = Mx::Webservice::GTR->new( url => $url, config => $config, logger => $logger );

$webservice->gtr_user( 'KBCSOAP01' );
$webservice->gtr_password( 'we3uCh5t' );

my $wsdl = $webservice->wsdl;

my ( $rv, $list ) = $webservice->get_xml_list( date => '20130502' );

my @list = @{$list};

print "return value: $rv\n";
print "list: @list\n";

my $name = $list[0];

my ( $size, $xml ) = $webservice->recover_xml( date => '20130502', name => $name . 'hj' );

print "size: $size\n";
print "xml: $xml\n";
