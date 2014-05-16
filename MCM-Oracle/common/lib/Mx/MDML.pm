package Mx::MDML;

use strict;
use warnings;

use Mx::Log;
use Carp;
use IO::File;
use XML::XPath;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;


    my $xml;
    if ( my $filename = $args{filename} ) {
        $logger->debug("initializing Mx::MDML object from file ($filename)");

        my $fh;
        unless( $fh = IO::File->new( $filename, '<' ) ) {
            $logger->logdie("unable to open $filename: $!");
        }

        while ( <$fh> ) {
            $xml .= $_;
        }

        $fh->close();
    }
    elsif ( $args{xml} ) {
        $logger->debug("initializing Mx::MDML object from string");

        $xml = $args{xml};
    }
    else {
        $logger->logdie('Mx::MDML initialisation: no xml or filename specified');
    }

    my $xpath = $self->{xpath} = XML::XPath->new( xml => $xml );

    my $nodeset = $xpath->find('/xc:XmlCache');

    unless ( $nodeset->size() == 1 ) {
        $logger->logdie("not a valid MDML document");
    }

    my $action = $self->{action} = $nodeset->get_node(1)->getAttribute('xc:action');

    $logger->info("Mx::MDML object initialized, action: $action");

    bless $self, $class; 
}

#----------#
sub action {
#----------#
    my ( $self ) = @_;


    return $self->{action};
}

#-------#
sub mds {
#-------#
    my ( $self ) = @_;


    unless ( $self->{mds} ) {
        my $logger = $self->{logger};
        my $nodeset = $self->{xpath}->find('/xc:XmlCache/xc:XmlCacheArea/mp:nickName');
    
        unless ( $nodeset->size() == 1 ) {
            $logger->logdie("not a valid MDML document");
        }

        my $mds = $self->{mds} = $nodeset->get_node(1)->getAttribute('xc:value');

        $logger->debug("Mx::MDML mds: $mds\n");
    }

    return $self->{mds};
}

#--------#
sub date {
#--------#
    my ( $self ) = @_;


    unless ( $self->{date} ) {
        my $logger = $self->{logger};
        my $nodeset = $self->{xpath}->find('/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date');
    
        unless ( $nodeset->size() == 1 ) {
            $logger->logdie("not a valid MDML document");
        }

        my $date = $self->{date} = $nodeset->get_node(1)->getAttribute('xc:value');

        $logger->debug("Mx::MDML date: $date\n");
    }

    return $self->{date};
}

#---------#
sub types {
#---------#
    my ( $self ) = @_;


    unless ( $self->{types} ) {
        my $logger = $self->{logger};
        my $nodeset = $self->{xpath}->find('/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date');
    
        my @types;
        unless ( $nodeset->size() == 1 ) {
            $logger->logdie("not a valid MDML document");
        }

        my $node = $nodeset->get_node(1);

        my %families;
        foreach my $child ( $node->getChildNodes ) {
            next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

            my $name = $child->getName();
            $families{$name} = 1;
        }

        foreach my $family ( keys %families ) {
            my $nodeset = $self->{xpath}->find("/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date/$family");

            my %classes;
            foreach my $node ( $nodeset->get_nodelist ) {
                foreach my $child ( $node->getChildNodes ) {
                    next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

                    my $name = $child->getName();
                    $classes{$name} = 1;
                }
            }

            foreach my $class ( keys %classes ) {
                push @types, $family . '/' . $class;
            
            }
        }

        $self->{types} = [ @types ];

        $logger->debug("Mx::MDML types: @types");
    }

    return @{$self->{types}};
}

#-------------#
sub vol_pairs {
#-------------#
    my ( $self ) = @_;


    unless ( $self->{vol_pairs} ) {
        my $logger = $self->{logger};
        my $nodeset = $self->{xpath}->find('/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date/fx:forex/fxvl:volatility/fxvl:pair');

        my @vol_pairs;
        foreach my $node ( $nodeset->get_nodelist ) {
            my $pair = $node->getAttribute('xc:value');
            push @vol_pairs, $pair;
        }

        $self->{vol_pairs} = [ @vol_pairs ];

        $logger->debug("Mx::MDML volatility pairs: @vol_pairs");
    }

    return @{$self->{vol_pairs}};
}

#--------#
sub vols {
#--------#
    my ( $self, %args ) = @_;


    my @vols;
    my $logger = $self->{logger};

    my $pair;
    unless ( $pair = $args{pair} ) {
        $logger->logdie("no pair specified");
    }

    my $nodeset = $self->{xpath}->find("/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date/fx:forex/fxvl:volatility/fxvl:pair[\@xc:value=\"$pair\"]/fxvl:maturity");

    foreach my $node ( $nodeset->get_nodelist ) {
        my $maturity = $node->getAttribute('xc:value');

        my $bid; my $ask;
        foreach my $child ( $node->getChildNodes ) {
            next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

            if ( $child->getName() eq 'mp:bid' ) {
                $bid = $child->string_value;
            }
            elsif ( $child->getName() eq 'mp:ask' ) {
                $ask = $child->string_value;
            }
        }

        push @vols, { $maturity => { bid => $bid, ask => $ask } };
    }

    return @vols;
}

#----------#
sub smiles {
#----------#
    my ( $self, %args ) = @_;


    my @smiles;
    my $logger = $self->{logger};

    my $pair;
    unless ( $pair = $args{pair} ) {
        $logger->logdie("no pair specified");
    }

    my $maturity;
    unless ( $maturity = $args{maturity} ) {
        $logger->logdie("no maturity specified");
    }

    my $nodeset = $self->{xpath}->find("/xc:XmlCache/xc:XmlCacheArea/mp:nickName/mp:date/fx:forex/fxsm:smile/fxsm:pair[\@xc:value=\"$pair\"]/fxsm:maturity[\@xc:value=\"$maturity\"]/fxsm:ordinate");

    foreach my $node ( $nodeset->get_nodelist ) {
        my $ordinate = $node->getAttribute('xc:value');

        my $bid; my $ask;
        foreach my $child ( $node->getChildNodes ) {
            next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

            if ( $child->getName() eq 'mp:bid' ) {
                $bid = $child->string_value;
            }
            elsif ( $child->getName() eq 'mp:ask' ) {
                $ask = $child->string_value;
            }
        }

        push @smiles, { $ordinate => { bid => $bid, ask => $ask } };
    }

    return @smiles;
}

#--------------#
sub vol_matrix {
#--------------#
    my ( $self, %args ) = @_;


    my @matrix; my @ordinates;
    my $logger = $self->{logger};

    my $pair;
    unless ( $pair = $args{pair} ) {
        $logger->logdie("no pair specified");
    }

    my $type = $args{type} || 'ask';
    unless ( $type eq 'bid' or $type eq 'ask' ) {
        $logger->logdie("wrong type ($type) specified, must be bid or ask");
    }

    my @vols = $self->vols( pair => $pair );

    my %ordinates;
    foreach my $vol ( @vols ) {
        my ( $maturity, $value ) = %{$vol};
        my $price = $value->{$type};

        my @smiles = $self->smiles( pair => $pair, maturity => $maturity );

        my %row;
        foreach my $smile ( @smiles ) {
            my ( $ordinate, $value ) = %{$smile};
            $ordinates{$ordinate} = 1;
            my $delta = $value->{$type};

            $row{$ordinate} = $price + $delta;
        }

        $row{'50.0'} = $price; 

        push @matrix, [ $maturity, \%row ];
    }

    $ordinates{'50.0'} = 1;

    @ordinates = sort { $a <=> $b } keys %ordinates;

    return ( \@matrix, \@ordinates );
}

#----------------#
sub mail_address {
#----------------#
    my ( $self ) = @_;


    unless ( $self->{mail_address} ) {
        my $logger = $self->{logger};
        my $nodeset = $self->{xpath}->find('/comment()');

        foreach my $node ( $nodeset->get_nodelist ) {
            my $string = $node->string_value;
            if ( $string =~ /mail_to:(\S+)/ ) {
                my $mail_address = $self->{mail_address} = $1;

                $logger->debug("Mx::MDML mail address: $mail_address");

                last;
            } 
        }
    }

    return $self->{mail_address};
}
   

1;
