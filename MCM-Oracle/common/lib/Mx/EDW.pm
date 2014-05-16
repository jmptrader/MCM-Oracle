package Mx::EDW;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use LWP::UserAgent;
use XML::XPath;
use Carp;

my $URL = 'http://cmutility.corp.lch.com/EDW/lchedwservice.asmx/EDWGetDefinition?edwId=';


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger}     = $logger;
	$self->{errorcode}  = 0;

    my $config = $args{config};

    my $edw_id = $config->retrieve('EDW_ID');

    $logger->debug("initializing EDW object, EDW id is $edw_id");

    $self->{config} = { EDW_ID => $edw_id };

    my $ua = LWP::UserAgent->new;

    my $response = $ua->get( $URL . $edw_id );

    if ( $response->is_success ) {
	    my $xpath = XML::XPath->new( xml => $response->content );

	    if ( $xpath->getNodeText('/EDWResult/Success') eq 'true' ) {
	        my $nodeset = $xpath->find('/EDWResult/Result/edw');

            unless ( $nodeset->size() == 1 ) {
                $logger->logdie("not a valid response");
            }

	        my $node = $nodeset->get_node(1);

	        $self->{type}        = $node->getAttribute('Type');
	        $self->{name}        = $node->getAttribute('Name');
	        $self->{description} = $node->getAttribute('Description');

	        foreach my $child ( $node->getChildNodes ) {
                next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

		        my $name  = $child->getAttribute('Name');
		        my $value = $child->getAttribute('Value') || '';

			    $self->{config}->{$name} = $value;
            }
        }
	    else {
	        $self->{errorcode}    = $xpath->getNodeText('/EDWResult/ErrorCode');
	        $self->{errormessage} = $xpath->getNodeText('/EDWResult/ErrorMessage');
        }
    }
    else {
        $self->{errorcode}    = 1;
        $self->{errormessage} = $response->status_line;
    }

    if ( $self->{errorcode} ) {
        $logger->error("EDW object initialization failed ($self->{errormessage}");
    }
    else {
        $logger->debug('EDW object successfully initialized');
    }

    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ($self, $key, $no_strict) = @_;


    unless ( exists $self->{config}->{$key} ) {
        return if $no_strict;
        $self->{logger}->logdie("using non-existing configuration parameter: $key");
    }

    return $self->{config}->{$key};
}

#-----------------#
sub add_to_config {
#-----------------#
    my ( $self, %hash ) = @_;


    while ( my ($key, $value ) = each %hash ) {
        $self->{config}->{$key} = $value;
    }
}

#------------#
sub get_keys {
#------------#
    my ( $self ) = @_;

    return keys %{$self->{config}};
}

#-------------#
sub check_key {
#-------------#
    my ( $self, $key ) = @_;


    exists $self->{config}->{$key};
}

#-----------#
sub set_key {
#-----------#
    my ( $self, $key, $value ) = @_;


    $self->{config}->{$key} = $value;
}

#--------#
sub hash {
#--------#
    my ( $self ) = @_;


	return $self->{config};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;


	return $self->{type};
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


	return $self->{name};
}

#---------------#
sub description {
#---------------#
    my ( $self ) = @_;


	return $self->{description};
}

#-------------#
sub errorcode {
#-------------#
    my ( $self ) = @_;


	return $self->{errorcode};
}

#----------------#
sub errormessage {
#----------------#
    my ( $self ) = @_;


	return $self->{errormessage};
}

1;
