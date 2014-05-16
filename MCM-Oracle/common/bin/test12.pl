#!/usr/bin/env perl

use warnings;

use LWP::UserAgent;
use Net::SSL;
use SOAP::Lite +trace => 'debug';
use Time::Piece;
use Time::Local;
use IO::File;

my $time = timelocal( 0, 0, 12, 24, 3, 113 );

my $t = localtime( $time );
my $xml_date = sprintf "%d", $t->mjd;

my $xml_name = 'RP6087_I401_20130424_150004_0.XML';
my $xml_file = 'registr.xml';

my $url = 'https://formacion.regis-tr.com:8082/regis_tr_xml_load/services/regis_tr_xml_load';

$ENV{HTTPS_PROXY}                  = 'https://internetproxy.servers.kbc.be:8080';
$ENV{HTTPS_PROXY_USERNAME}         = 'u03703';
$ENV{HTTPS_PROXY_PASSWORD}         = 'compu99';
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $registr_user     = 'KBCSOAP01';
my $registr_pass_old = 'RegisTR01';
my $registr_pass     = 'we3uCh5t';

if ( 0 ) {

my $ua = LWP::UserAgent->new() ;

$ua->timeout(10);

my $req = HTTP::Request->new('GET', $url . '?wsdl' );

my $response = $ua->request($req);
 
if ($response->is_success) {
    print $response->decoded_content;
}
else {
   die $response->status_line;
}
}

my $soap = SOAP::Lite->service( $url . '?wsdl' );

$soap->proxy( $url );
#$soap->endpoint( $url );

#$soap->default_ns('urn:http://regis_tr_xml_load');
$soap->envprefix('soapenv');

if ( 0 ) {
my $result = $soap->call( 'change_password',
    SOAP::Data->name('user')->value( $registr_user ),
    SOAP::Data->name('password')->value( $registr_pass_old ),
    SOAP::Data->name('new_password')->value( $registr_pass )
);

die $result->fault->{ faultstring } if ( $result->fault );

print $result->result, "\n";
}

if ( 0 ) {
my $result = $soap->call( 'get_xml_list',
    SOAP::Data->name('user')->value( $registr_user ),
    SOAP::Data->name('password')->value( $registr_pass ),
    SOAP::Data->name('xml_date')->value( \SOAP::Data->name('dateValue')->value( $xml_date )->type('xsd:double') )->type('tns3:Date')
);

die $result->fault->{ faultstring } if ( $result->fault );

print $result->result, "\n";
}

if ( 0 ) {
my $result = $soap->call( 'recover_xml',
    SOAP::Data->name('user')->value( $registr_user ),
    SOAP::Data->name('password')->value( $registr_pass ),
    SOAP::Data->name('xml_date')->value( \SOAP::Data->name('dateValue')->value( $xml_date )->type('xsd:double') )->type('tns3:Date'),
    SOAP::Data->name('xml_name')->value( $xml_name ),
);

die $result->fault->{ faultstring } if ( $result->fault );

print $result->result, "\n";
}

if ( 1 ) {
my $fh = IO::File->new( $xml_file, '<' );
my $loaded_xml = '';
while ( <$fh> ) {
    chomp;
    $loaded_xml .= $_;
}
$loaded_xml =~ s/>\s+</></g;
$fh->close;

my $result = $soap->call( 'send_xml',
    SOAP::Data->name('user')->value( $registr_user ),
    SOAP::Data->name('password')->value( $registr_pass ),
    SOAP::Data->name('loaded_xml')->value( $loaded_xml )
);

die $result->fault->{ faultstring } if ( $result->fault );

print $result->result, "\n";
}
