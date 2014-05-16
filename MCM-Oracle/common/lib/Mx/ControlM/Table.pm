package Mx::ControlM::Table;

use strict;
use warnings;

use Mx::Log;
use Mx::ControlM::Job;
use XML::XPath;
use IO::File;
use Carp;

#
# Attributes
#
# $name
# @jobs
# @auto_edit_vars
# @in_conditions
# @out_conditions
# @err_conditions
# @calendars
# $xml
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

	unless ( $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of ControlM table (config)");
    }

    my $xml;
    if ( my $file = $args{file} ) {
        my $fh;
        unless ( $fh = IO::File->new( $file, '<' ) ) {
            $logger->logdie("unable to open $file: $!");
        }

        while ( <$fh> ) {
            $xml .= $_;
        }

        $fh->close;
    }
    elsif ( $xml = $args{xml} ) {
    }
    else {
        $logger->logdie("missing argument in initialisation of ControlM table (xml)");
    }

    $self->{xml} = $xml;
	my $edw = $self->{edw} = $args{edw};

    my $xpath = XML::XPath->new( xml => $xml );

    my $nodeset = $xpath->find('/DEFTABLE/SMART_TABLE');

    unless ( $nodeset->size() == 1 ) {
        $logger->logdie("invalid xml");
    }

    my $node = $nodeset->get_node(1);

    $self->{name} = $node->getAttribute('TABLE_NAME');

	$self->{name} =~ s/@(\w+)@/$edw->retrieve($1)/ge if $edw;

    bless $self, $class;

    $self->{jobs}           = [];
    $self->{in_conditions}  = [];
    $self->{out_conditions} = [];
    $self->{err_conditions} = [];
    foreach my $child ( $node->getChildNodes ) {
        next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

        my $name = $child->getName();

		if ( $name eq 'JOB' ) {
			if ( my $job = Mx::ControlM::Job->new( xml => $child->toString, edw => $args{edw}, config => $self->{config}, logger => $logger ) ) {
                push @{$self->{jobs}}, $job;
            }
        }
        elsif ( $name eq 'INCOND' ) {
            if ( my ( $rc, $in_condition ) = $self->_parse_in_condition( node => $child, logger => $logger ) ) {
				if ( $rc ) {
                    push @{$self->{in_conditions}}, $in_condition;
                }
				else {
                    push @{$self->{err_conditions}}, $in_condition;
                }
            }
        }
        elsif ( $name eq 'OUTCOND' ) {
            if ( my ( $rc, $out_condition ) = $self->_parse_out_condition( node => $child, logger => $logger ) ) {
				if ( $rc ) {
                    push @{$self->{out_conditions}}, $out_condition;
                }
				else {
                    push @{$self->{err_conditions}}, $out_condition;
                }
            }
        }
        elsif ( $name eq 'AUTOEDIT2' ) {
            if ( my $auto_edit_var = $self->_parse_auto_edit_var( node => $child, logger => $logger ) ) {
                push @{$self->{auto_edit_vars}}, $auto_edit_var;
            }
        }
        elsif ( $name eq 'RULE_BASED_CALENDAR' ) {
            if ( my $calendar = $self->_parse_calendar( node => $child, logger => $logger ) ) {
                push @{$self->{calendars}}, $calendar;
            }
        }
    }

	return $self;
}

#---------#
sub store {
#---------#
    my ( $self, %args ) = @_;


    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $self->{logger}->logdie("missing argument in C^M table store (db_audit)");
    }

    $self->{id} = $db_audit->record_ctrlm_table(
      name              => $self->{name},
      nr_jobs           => scalar @{$self->{jobs}},
      nr_in_conditions  => scalar @{$self->{in_conditions}},
      nr_out_conditions => scalar @{$self->{out_conditions}},
      nr_err_conditions => scalar @{$self->{err_conditions}}
    );
}

#-----------------------#
sub _parse_in_condition {
#-----------------------#
    my ( $self, %args ) = @_;


	my $node   = $args{node};
	my $logger = $args{logger};

	my $and_or = $node->getAttribute('AND_OR');
	my $name   = $node->getAttribute('NAME');

	if ( $name =~ /^[^:]*:(.*)-TO-[^:]*:(.*)$/ ) {
        my $from = $1;
		my $to   = $2;
		if ( $to ne $self->{name} ) {
			$logger->error("table $self->{name}: invalid in-condition: $name");
		    return ( 0, { name => $name, type => 'IN' } );
        }
		return ( 1, { jobname => $from, and_or => $and_or } );
    }
	else {
        $logger->error("table $self->{name}: invalid in-condition: $name");
	    return ( 0, { name => $name, type => 'IN' } );
    }
}

#------------#
sub dump_xml {
#------------#
    my ( $self, %args ) = @_;


    my $file = $args{file} || ( $self->{config}->CTRLMDIR . '/' . $self->{name} . '.xml' );

    my $fh;
    unless ( $fh = IO::File->new( $file, '>' ) ) {
        $self->{logger}->logdie("unable to open $file: $!");
    }

    print $fh $self->{xml};

    $fh->close;

    $self->{logger}->info("xml of table $self->{name} dumped to $file");
}

#------------------------#
sub _parse_out_condition {
#------------------------#
    my ( $self, %args ) = @_;


	my $node   = $args{node};
	my $logger = $args{logger};

	return if $node->getAttribute('SIGN') eq 'DEL';

	my $name = $node->getAttribute('NAME');

	if ( $name =~ /^[^:]*:(.*)-TO-[^:]*:(.*)$/ ) {
        my $from = $1;
		my $to   = $2;
		if ( $from ne $self->{name} ) {
			$logger->error("table $self->{name}: invalid out-condition: $name");
            return ( 0, { name => $name, type => 'OUT' } );
        }
        return ( 1, { jobname => $to } );
    }
	else {
        $logger->error("table $self->{name}: invalid out-condition: $name");
        return ( 0, { name => $name, type => 'OUT' } );
    }
}

#------------------------#
sub _parse_auto_edit_var {
#------------------------#
    my ( $self, %args ) = @_;


    my $node   = $args{node};
    my $logger = $args{logger};

    my $name = $node->getAttribute('NAME');
    my $value= $node->getAttribute('VALUE');

    $name =~ s/^%%//;

    return { name => $name, value => $value };
}

#-------------------#
sub _parse_calendar {
#-------------------#
    my ( $self, %args ) = @_;


    my $node   = $args{node};
    my $logger = $args{logger};

    my $name = $node->getAttribute('NAME');

    return { name => $name };
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

#--------#
sub jobs {
#--------#
    my ( $self ) = @_;


	return @{$self->{jobs}};
}

1;
