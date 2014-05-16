package Mx::ControlM::Job;

use strict;
use warnings;

use Mx::Log;
use XML::XPath;
use IO::File;
use Carp;

#
# Attributes
#
# $name
# $table
# $job_type
# $task_type
# $group
# $owner
# $node_id
# $description
# @auto_edit_vars
# @in_conditions
# @out_conditions
# @err_conditions
# @calendars
# @ctrl_resources
# @quant_resources
# @shouts
# $xml
#

my $XML_DECLARATION = '<?xml version="1.0" encoding="utf-8"?>';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

	unless ( $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of ControlM job (config)");
    }

	if ( $args{table} && $args{name} ) {
        $args{file} = $self->{config}->CTRLMDIR . '/' . $args{table} . '/' . $args{name} . '.xml';
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
        $logger->logdie("missing argument in initialisation of ControlM job (xml)");
    }

    $self->{xml} = $xml;
	my $edw = $self->{edw} = $args{edw};

    my $xpath = XML::XPath->new( xml => $xml );

    my $nodeset = $xpath->find('/JOB');

    unless ( $nodeset->size() == 1 ) {
        $logger->logdie("invalid xml");
    }

    my $node = $nodeset->get_node(1);

    $self->{name}        = $node->getAttribute('JOBNAME');
    $self->{table}       = $node->getAttribute('PARENT_TABLE');
    $self->{job_type}    = $node->getAttribute('APPL_FORM') || 'OS';
    $self->{task_type}   = $node->getAttribute('TASKTYPE');
    $self->{group}       = $node->getAttribute('GROUP');
    $self->{owner}       = $node->getAttribute('OWNER');
    $self->{description} = $node->getAttribute('DESCRIPTION');
    $self->{node_id}     = $node->getAttribute('NODEID');

	$self->{table} =~ s/@(\w+)@/$edw->retrieve($1)/ge if $edw;
	$self->{owner} =~ s/@(\w+)@/$edw->retrieve($1)/ge if $edw;

    bless $self, $class;

	$self->{ctrl_resources}  = [];
	$self->{quant_resources} = [];
	$self->{in_conditions}   = [];
	$self->{out_conditions}  = [];
	$self->{err_conditions}  = [];
    foreach my $child ( $node->getChildNodes ) {
        next unless $child->getNodeType eq XML::XPath::Node::ELEMENT_NODE;

        my $name = $child->getName();

        if ( $name eq 'INCOND' ) {
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
        elsif ( $name eq 'RULE_BASED_CALENDARS' ) {
            if ( my $calendar = $self->_parse_calendar( node => $child, logger => $logger ) ) {
                push @{$self->{calendars}}, $calendar;
            }
        }
        elsif ( $name eq 'CONTROL' ) {
            if ( my $resource = $self->_parse_control_resource( node => $child, logger => $logger ) ) {
                push @{$self->{ctrl_resources}}, $resource;
            }
        }
        elsif ( $name eq 'QUANTITATIVE' ) {
            if ( my $resource = $self->_parse_quantitative_resource( node => $child, logger => $logger ) ) {
                push @{$self->{quant_resources}}, $resource;
            }
        }
        elsif ( $name eq 'SHOUT' ) {
            if ( my $shout = $self->_parse_shout( node => $child, logger => $logger ) ) {
                push @{$self->{shouts}}, $shout;
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
		$self->{logger}->logdie("missing argument in C^M job store (db_audit)");
    }

	$self->{id} = $db_audit->record_ctrlm_job(
	  table             => $self->{table},
	  name              => $self->{name},
	  job_type          => $self->{job_type},
	  task_type         => $self->{task_type},
	  group             => $self->{group},
	  owner             => $self->{owner},
	  node_id           => $self->{node_id},
	  description       => $self->{description},
	  nr_in_conditions  => scalar @{$self->{in_conditions}},
	  nr_out_conditions => scalar @{$self->{out_conditions}},
	  nr_err_conditions => scalar @{$self->{err_conditions}},
	  nr_resources      => scalar @{$self->{ctrl_resources}} + scalar @{$self->{quant_resources}}
    );
}

#------------#
sub dump_xml {
#------------#
    my ( $self, %args ) = @_;


	my $file;
	unless ( $file = $args{file} ) {
		my $dir = $self->{config}->CTRLMDIR . '/' . $self->{table};

		unless ( -d $dir ) {
			unless ( mkdir $dir ) {
				$self->{logger}->logdie("unable to create $dir: $!");
            }
        }

		$file = $dir . '/' . $self->{name} . '.xml';
    }

	my $fh;
	unless ( $fh = IO::File->new( $file, '>' ) ) {
		$self->{logger}->logdie("unable to open $file: $!");
    }

    print $fh "$XML_DECLARATION\n";

    print $fh "$self->{xml}\n";

	$fh->close;

	$self->{logger}->info("xml of job $self->{name}, table $self->{table} dumped to $file");
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
			$logger->error("table $self->{table}, job $self->{name}: invalid in-condition: $name");
			return ( 0, { name => $name, type => 'IN' } );
        }
		return ( 1, { jobname => $from, and_or => $and_or } );
    }
	else {
        $logger->error("table $self->{table}, job $self->{name}: invalid in-condition: $name");
		return ( 0, { name => $name, type => 'IN' } );
    }
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
			$logger->error("table $self->{table}, job $self->{name}: invalid out-condition: $name");
			return ( 0, { name => $name, type => 'OUT' } );
        }
        return ( 1, { jobname => $to } );
    }
	else {
        $logger->error("table $self->{table}, job $self->{name}: invalid out-condition: $name");
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

#---------------------------#
sub _parse_control_resource {
#---------------------------#
    my ( $self, %args ) = @_;


    my $node   = $args{node};
    my $logger = $args{logger};

    my $name      = $node->getAttribute('NAME');
    my $exclusive = ( $node->getAttribute('TYPE') eq 'E' ) ? 'YES' : 'NO';

    return { name => $name, exclusive => $exclusive };
}

#--------------------------------#
sub _parse_quantitative_resource {
#--------------------------------#
    my ( $self, %args ) = @_;


    my $node   = $args{node};
    my $logger = $args{logger};

    my $name      = $node->getAttribute('NAME');
    my $quantity  = $node->getAttribute('QUANT');

    return { name => $name, quantity => $quantity };
}

#----------------#
sub _parse_shout {
#----------------#
    my ( $self, %args ) = @_;


    my $node   = $args{node};
    my $logger = $args{logger};

    my $destination = $node->getAttribute('DEST');
    my $message     = $node->getAttribute('MESSAGE');

    return { destination => $destination, message => $message };
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


	return $self->{name};
}

#---------#
sub table {
#---------#
    my ( $self ) = @_;


	return $self->{table};
}

#------------#
sub job_type {
#------------#
    my ( $self ) = @_;


	return $self->{job_type};
}

#-------------#
sub task_type {
#-------------#
    my ( $self ) = @_;


	return $self->{task_type};
}

#---------#
sub group {
#---------#
    my ( $self ) = @_;


	return $self->{group};
}

#---------#
sub owner {
#---------#
    my ( $self ) = @_;


	return $self->{owner};
}

#-----------#
sub node_id {
#-----------#
    my ( $self ) = @_;


	return $self->{node_id};
}

#---------------#
sub description {
#---------------#
    my ( $self ) = @_;


	return $self->{description};
}

#-----------------#
sub in_conditions {
#-----------------#
    my ( $self ) = @_;


	return @{$self->{in_conditions}};
}

#------------------#
sub out_conditions {
#------------------#
    my ( $self ) = @_;


	return @{$self->{out_conditions}};
}

#------------------#
sub err_conditions {
#------------------#
    my ( $self ) = @_;


	return @{$self->{err_conditions}};
}

#------------------#
sub auto_edit_vars {
#------------------#
    my ( $self ) = @_;


	return @{$self->{auto_edit_vars}};
}

#------------------#
sub ctrl_resources {
#------------------#
    my ( $self ) = @_;


	return @{$self->{ctrl_resources}};
}

#-------------------#
sub quant_resources {
#-------------------#
    my ( $self ) = @_;


	return @{$self->{quant_resources}};
}


1;
