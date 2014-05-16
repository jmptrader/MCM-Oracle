package Mx::ProcScriptXML;

use strict;
use warnings;

use Mx::Log;
use XML::XPath;
use IO::File;
use Carp;

#
# Attributes:
#
# $name
# $xml
# @items
# $nr_items
#
# $item_name
# $item_unit
# $item_label
#

my %scanner_units = (
  'EOD.ACCOUNTING.ENTRY.GENERATION.TRADE' => 1,
  'DATAMART.REPORTING.BATCHES.FEEDERS'    => 1,
  'EVENT.AUTOMATION.FIXING'               => 1,
);

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $self->{logger} = $args{logger} or croak 'no logger defined.';

    my $xml;
    unless ( $xml = $args{xml} ) {
        $logger->logdie("missing argument in initialisation of ProcScriptXML (xml)");
    }

    if ( $xml =~ /^\s*<\?xml/ ) {
        $self->{xml} = $xml;
    }
    elsif ( -f $xml ) {
        my $fh;
        unless ( $fh = IO::File->new( $xml, '<' ) ) {
            $logger->logdie("cannot open $xml: $!");
        }

        $self->{xml} = '';
        while ( <$fh> ) {
            $self->{xml} .= $_;
        }

        $fh->close();
    }
    else {
        $logger->logdie("not a valid xml argument");
    }

    unless ( $self->{xpath} = XML::XPath->new( xml => $self->{xml} ) ) {
        $logger->logdie("unable to parse ProcScriptXML xml: $!");
    }

    my $nr_items;
    if ( my @items = $self->{xpath}->findnodes( 'Script/Items/Item' ) ) {
        $self->{items}    = \@items;
        $self->{nr_items} = $nr_items = @items;
    }
    else {
        $self->{items}    = [];
        $self->{nr_items} = $nr_items = 0;
    }

    my $name = $self->{name} = $self->{xpath}->getNodeText('/Script/Name');

    $logger->debug("ProcScriptXML $name initialized, $nr_items item(s)");

    bless $self, $class;
}

#--------#
sub _new {
#--------#
    my ( %args ) = @_;


    my $self = {};

    $self->{logger}   = $args{logger};
    $self->{xml}      = $args{xml};
    $self->{name}     = $args{name};
    $self->{xpath}    = XML::XPath->new( xml => $self->{xml} );
    $self->{items}    = [ $self->{xpath}->findnodes( 'Script/Items/Item' ) ];  
    $self->{nr_items} = 1;

    bless $self, 'Mx::ProcScriptXML';
}

#---------#
sub split {
#---------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( $self->{nr_items} <= 1 ) {
        $logger->warn("unable to split a ProcScriptXML with only one item");
        return ( $self );
    }

    my $rest = '';
    foreach my $node ( $self->{xpath}->findnodes( '/Script/*[not(self::Items)]' ) ) {
        $rest .= $node->toString . "\n";
    }

    my @list = ();
    foreach my $item ( @{$self->{items}} ) {
        my $xml = "<?xml version=\"1.0\"?>\n";
        $xml .= "<Script>\n";
        $xml .= $rest;
        $xml .= "<Items>\n";
        $xml .= $item->toString . "\n";
        $xml .= "</Items>\n";
        $xml .= "</Script>\n";

        push @list, _new( xml => $xml, name => $self->{name}, logger => $logger );
    }

    return @list;
}

#-------------#
sub item_unit {
#-------------#
    my ( $self ) = @_;


    if ( exists $self->{item_unit} ) {
        return $self->{item_unit};
    }

    $self->{item_unit} = undef;

    if ( $self->{nr_items} != 1 ) {
        return;
    }

    my $unit_set = $self->{xpath}->find('/Script/Items/Item/Unit');

    my $item_unit;
    if ( $unit_set->size() == 1 ) {
        $item_unit = $unit_set->get_node(1)->string_value;
    }

    if ( $item_unit ) {
        $self->{item_unit} = $item_unit;
        return $item_unit;
    }
    else {
        $self->{logger}->error("cannot determine ProcScriptXML item unit");
        return;
    }
}

#-------------------#
sub is_scanner_unit {
#-------------------#
    my ( $self, $unit ) = @_;


    if ( $scanner_units{ $unit } ) {
        return 1;
    }

    return 0;
}

#-------------#
sub item_name {
#-------------#
    my ( $self ) = @_;


    if ( exists $self->{item_name} ) {
        return $self->{item_name};
    }

    $self->{item_name} = undef;

    if ( $self->{nr_items} != 1 ) {
        return;
    }

    my $name_set = $self->{xpath}->find('/Script/Items/Item/Name');

    my $item_name;
    if ( $name_set->size() == 1 ) {
        $item_name = $name_set->get_node(1)->string_value;
    }

    if ( defined $item_name ) {
        $self->{item_name} = $item_name;
        return $item_name;
    }
    else {
        $self->{logger}->error("cannot determine ProcScriptXML item name");
        return;
    }
}

#--------------#
sub item_label {
#--------------#
    my ( $self ) = @_;


    if ( exists $self->{item_label} ) {
        return $self->{item_label};
    }

    $self->{item_label} = undef;

    if ( $self->{nr_items} != 1 ) {
        return;
    }

    my $label_set = $self->{xpath}->find('/Script/Items/Item/Parameter/Label2');

    my $item_label;
    if ( $label_set->size() == 1 ) {
        $item_label = $label_set->get_node(1)->string_value;
    }

    if ( $item_label ) {
        $self->{item_label} = $item_label;
        return $item_label;
    }
    else {
        $self->{logger}->error("cannot determine ProcScriptXML item label");
        return;
    }
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

#------------#
sub nr_items {
#------------#
    my ( $self ) = @_;


    return $self->{nr_items};
}

#-------#
sub xml {
#-------#
    my ( $self ) = @_;


    return $self->{xml};
}

1;
