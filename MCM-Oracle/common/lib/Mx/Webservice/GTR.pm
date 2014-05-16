package Mx::Webservice::GTR;

use strict;
use warnings;

use LWP::UserAgent;
use Net::SSL;
use SOAP::Lite;
#use SOAP::Lite +trace => 'debug';
use Time::Piece;
use Time::Local;
use IO::File;
use Data::Dumper;
use Carp;

use Mx::Log;
use Mx::Config;
use Mx::Account;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $args{logger} or croak 'no logger defined.';
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie('missing argument in initialisation of webservice (config)');
    }

    my $url;
    unless ( $url = $self->{url} = $args{url} ) {
        $logger->logdie('missing argument in initialisation of webservice (url)');
    }

    my $proxy_account;
    unless ( $proxy_account = Mx::Account->new( name => $config->PROXY_USER, config => $config, logger => $logger ) ) {
        $logger->logdie("cannot retrieve proxy account");
    }

    $ENV{HTTPS_PROXY}                  = $config->PROXY_HOST;
    $ENV{HTTPS_PROXY_USERNAME}         = $proxy_account->name;
    $ENV{HTTPS_PROXY_PASSWORD}         = $proxy_account->password;
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

    my $soap;
    unless ( $soap = SOAP::Lite->new( proxy => $url, envprefix => 'soapenv' ) ) {
        $logger->logdie("cannot initialize soap connection: $!");
    }

    $self->{soap} = $soap;

    $self->{gtr_user} = $args{gtr_user};
    $self->{gtr_pass} = $args{gtr_password};

    $self->{debug} = ( $args{debug} ) ? 1 : 0;

    bless $self, $class;
}

#--------#
sub wsdl {
#--------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $url    = $self->{url};

    my $ua = LWP::UserAgent->new();

    $ua->timeout(10);

    my $request = HTTP::Request->new( 'GET', $url . '?wsdl' );

    my $response = $ua->request( $request );
    
    unless ( $response->is_success ) {
        $logger->error( $response->status_line );
        return;
    }

    return $response->decoded_content;
}

#------------#
sub gtr_user {
#------------#
    my ( $self, $gtr_user ) = @_;


    $self->{gtr_user} = $gtr_user if $gtr_user;
    return $self->{gtr_user};
}

#----------------#
sub gtr_password {
#----------------#
    my ( $self, $gtr_pass ) = @_;


    $self->{gtr_pass} = $gtr_pass if $gtr_pass;
    return $self->{gtr_pass};
}

#----------------#
sub get_xml_list {
#----------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $soap       = $self->{soap};
    my $gtr_user   = $self->{gtr_user};
    my $gtr_pass   = $self->{gtr_pass};
    my $debug_response = '';

    unless ( $gtr_user && $gtr_pass ) {
        $logger->logdie("get_xml_list: GTR user and/or password are not initialized");
    }

    my $date;
    unless ( $date = $args{date} ) {
        $logger->logdie("get_xml_list: no date specified");
    }

    my $xml_date = _convert2mjd( $date, $logger );

    my $som = $soap->call(
        'get_xml_list',
        SOAP::Data->name( 'user'     )->value( $gtr_user ),
        SOAP::Data->name( 'password' )->value( $gtr_pass ),
        SOAP::Data->name( 'xml_date' )->value( \SOAP::Data->name( 'dateValue' )->value( $xml_date )->type( 'xsd:double' ) )->type( 'tns3:Date' )
    );

    unless ( $som ) {
        my $errorstring = "soap call failed: $!";
        $logger->error("get_xml_list: $errorstring");
        return( 0, $errorstring, $debug_response );
    }

    if ( $self->{debug} ) {
        $debug_response = _debug_response( $som, $logger );
    }

    if ( $som->fault ) {
        my $errorstring = $som->fault->{ faultstring };
        $logger->error("get_xml_list: $errorstring");
        return( 0, $errorstring, $debug_response );
    }

    my $rc = $som->result;

    my $list = [];
    if ( $rc > 0 ) {
        $list = $som->paramsout;
    }

    return ( $rc, $list, $debug_response );
}

#---------------#
sub recover_xml {
#---------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $soap       = $self->{soap};
    my $gtr_user   = $self->{gtr_user};
    my $gtr_pass   = $self->{gtr_pass};
    my $debug_response = '';

    unless ( $gtr_user && $gtr_pass ) {
        $logger->logdie("recover_xml: GTR user and/or password are not initialized");
    }

    my $date;
    unless ( $date = $args{date} ) {
        $logger->logdie("recover_xml: no date specified");
    }

    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("recover_xml: no name specified");
    }

    my $xml_date = _convert2mjd( $date, $logger );

    my $som = $soap->call(
        'recover_xml',
        SOAP::Data->name( 'user'     )->value( $gtr_user ),
        SOAP::Data->name( 'password' )->value( $gtr_pass ),
        SOAP::Data->name( 'xml_date' )->value( \SOAP::Data->name( 'dateValue' )->value( $xml_date )->type( 'xsd:double' ) )->type( 'tns3:Date' ),
        SOAP::Data->name( 'xml_name' )->value( $name )
    );

    unless ( $som ) {
        my $errorstring = "soap call failed: $!";
        $logger->error("recover_xml_list: $errorstring");
        return( 0, $errorstring, $debug_response );
    }

    if ( $self->{debug} ) {
        $debug_response = _debug_response( $som, $logger );
    }

    if ( $som->fault ) {
        my $errorstring = $som->fault->{ faultstring };
        $logger->error("recover_xml: $errorstring");
        return ( 0, $errorstring, $debug_response );
    }

    my $rc = $som->result;

    my $xml;
    if ( $rc == 0 ) {
        $xml = $som->body->{recover_xmlResponse}->{xml};
    }

    return ( $rc, $xml, $debug_response );
}

#-------------------#
sub change_password {
#-------------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $soap       = $self->{soap};
    my $gtr_user   = $self->{gtr_user};
    my $gtr_pass   = $self->{gtr_pass};
    my $debug_response = '';

    unless ( $gtr_user && $gtr_pass ) {
        $logger->logdie("change_password: GTR user and/or password are not initialized");
    }

    my $password;
    unless ( $password = $args{password} ) {
        $logger->logdie("change_password: no password specified");
    }

    my $som = $soap->call(
        'change_password',
        SOAP::Data->name( 'user'         )->value( $gtr_user ),
        SOAP::Data->name( 'password'     )->value( $gtr_pass ),
        SOAP::Data->name( 'new_password' )->value( $password )
    );

    unless ( $som ) {
        my $errorstring = "soap call failed: $!";
        $logger->error("change_password: $errorstring");
        return( 0, $errorstring, $debug_response );
    }

    if ( $self->{debug} ) {
        $debug_response = _debug_response( $som, $logger );
    }

    if ( $som->fault ) {
        my $errorstring = $som->fault->{ faultstring };
        $logger->error("change_password: $errorstring");
        return ( 0, $errorstring, $debug_response );
    }

    my $rc = $som->result;

    if ( $rc == 0 ) {
        my $string = "new password of GTR user $gtr_user set to $password";
        $logger->info("change_password: $string");
        $self->{gtr_pass} = $password;
        return ( 1, $string, $debug_response );
    }

    my $errorstring = "password of GTR user $gtr_user could not be set to $password";
    $logger->error("change_password: $errorstring");

    return ( 0, $errorstring, $debug_response );
}

#------------#
sub send_xml {
#------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $soap       = $self->{soap};
    my $gtr_user   = $self->{gtr_user};
    my $gtr_pass   = $self->{gtr_pass};
    my $debug_response = '';

    unless ( $gtr_user && $gtr_pass ) {
        $logger->logdie("send_xml: GTR user and/or password are not initialized");
    }

    my $xml = $args{xml};
    unless ( $xml ) {
        if ( my $file = $args{file} ) {
            my $fh;
            unless ( $fh = IO::File->new( $file, '<' ) ) {
                $logger->logdie("send_xml: cannot open $file: $!");
            }
            while ( <$fh> ) {
                $xml .= $_;
            }
            $fh->close;
        }
        else {
            $logger->logdie("send_xml: no xml or no file specified");
        }
    }

    $xml =~ s/>\s+</></g;

    my $som = $soap->call(
        'send_xml',
        SOAP::Data->name( 'user'       )->value( $gtr_user ),
        SOAP::Data->name( 'password'   )->value( $gtr_pass ),
        SOAP::Data->name( 'loaded_xml' )->value( $xml )
    );

    unless ( $som ) {
        my $errorstring = "soap call failed: $!";
        $logger->error("send_xml: $errorstring");
        return( 0, $errorstring, $debug_response );
    }

    if ( $self->{debug} ) {
        $debug_response = _debug_response( $som, $logger );
    }

    if ( $som->fault ) {
        my $errorstring = $som->fault->{ faultstring };
        $logger->error("send_xml: $errorstring");
        return ( 0, $errorstring, $debug_response );
    }

    my $result = $som->result;

    unless ( $result ) {
        my $string = "upload successfull"; 
        $logger->info("send_xml: $string");
        return ( 1, $string, $debug_response );
    }

    $logger->error("send_xml: $result");

    return ( 0, $result, $debug_response );
}

#----------------#
sub _convert2mjd {
#----------------#
    my ( $date, $logger ) = @_;


    my $mjd; 
    if ( $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
        $logger->info("date is $date");

        my $year  = $1 - 1900;
        my $month = $2 - 1;
        my $day   = $3;

        unless ( ( $year > 100 && $year < 200 ) && ( $month >= 0 && $month < 12 ) && ( $day > 0  && $day <= 31 ) ) {
            $logger->logdie("wrong date format, must be YYYYMMDD");
        }

        my $time = timelocal( 0, 0, 12, $day, $month, $year );

        my $t = localtime( $time );

        $mjd = sprintf "%d", $t->mjd;

        $logger->info("modified Julian date is $mjd");
    }
    else {
        $logger->logdie("wrong date specified ($date), must be YYYYMMDD");
    }

    return $mjd;
}

#-------------------#
sub _debug_response {
#-------------------#
    my ( $som, $logger ) = @_;

    $Data::Dumper::Terse = 1;
    my $hash = $som->body;
    my $response = Dumper( $hash );
    $logger->debug("debug response: $response");
    return $response;
} 

1;
