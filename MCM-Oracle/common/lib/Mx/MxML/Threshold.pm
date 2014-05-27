package Mx::MxML::Threshold;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;
use Mx::MxML::Task;

#
# Attributes:
#

my @QUEUE_TASKTYPES    = ();
my $MESSAGE_THROUGHPUT = 0;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of MxML threshold (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of MxML threshold (config)");
    }

    my $mxml_threshold_configfile = $config->retrieve('MXML_THRESHOLDSFILE');
    my $mxml_threshold_config     = Mx::Config->new( $mxml_threshold_configfile );

    my $mxml_threshold_ref;
    unless ( $mxml_threshold_ref = $mxml_threshold_config->retrieve("MXML_THRESHOLDS.$name") ) {
        $logger->logdie("MxML threshold '$name' is not defined in the configuration file");
    }
 
    foreach my $param (qw( order taskname tasktype workflow nr_messages_warn nr_messages_fail timeout_warn timeout_fail )) {
        unless ( exists $mxml_threshold_ref->{$param} ) {
            $logger->logdie("parameter '$param' for MxML threshold '$name' is not defined in the configuration file");
        }
        $self->{$param} = $mxml_threshold_ref->{$param};
    }

    $self->{warning_address} = $mxml_threshold_ref->{warning_address};
    $self->{fail_address}    = $mxml_threshold_ref->{fail_address};

    bless $self, $class;

    $logger->debug("threshold '$name' is initialized");

    return $self;
}


#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @mxml_thresholds = ();
 
    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $mxml_threshold_configfile = $config->retrieve('MXML_THRESHOLDSFILE');
    my $mxml_threshold_config     = Mx::Config->new( $mxml_threshold_configfile );
 
    $logger->debug("scanning the configuration file for MxML thresholds");
 
    my $mxml_threshold_ref;
    unless ( $mxml_threshold_ref = $mxml_threshold_config->MXML_THRESHOLDS ) {
        $logger->logdie("cannot access the MxML threshold section in the configuration file");
    }
 
    foreach my $name ( keys %{$mxml_threshold_ref} ) {
        next if $name eq 'queue_tasktype' or $name eq 'message_throughput';
        my $mxml_threshold = Mx::MxML::Threshold->new( name => $name, config => $config, logger => $logger );
        push @mxml_thresholds, $mxml_threshold if $mxml_threshold;
    }

    @mxml_thresholds = sort { $a->{order} <=> $b->{order} } @mxml_thresholds;
 
    return @mxml_thresholds;
}


#---------#
sub apply {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $task;
    unless ( $task = $args{task} ) {
        $logger->error("no task supplied for threshold application");
        return;
    }

    if ( my $taskname = $self->{taskname} ) {
        if ( $task->{taskname} !~ /^$taskname$/ ) {
            return;
        }
    }

    if ( $self->{tasktype} && $self->{tasktype} ne $task->{tasktype} ) {
        return;
    }

    if ( $self->{workflow} && $self->{workflow} ne $task->{workflow} ) {
        return;
    }

    $task->{nr_messages_warn} = $self->{nr_messages_warn};
    $task->{nr_messages_fail} = $self->{nr_messages_fail};
    $task->{timeout_warn}     = $self->{timeout_warn};
    $task->{timeout_fail}     = $self->{timeout_fail};
    $task->{warning_address}  = $self->{warning_address};
    $task->{fail_address}     = $self->{fail_address};
}

#-------------------#
sub queue_tasktypes {
#-------------------#
    my ( $class, %args ) = @_;


    if ( @QUEUE_TASKTYPES ) {
        return @QUEUE_TASKTYPES;
    }

    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $mxml_threshold_configfile = $config->retrieve('MXML_THRESHOLDSFILE');
    my $mxml_threshold_config     = Mx::Config->new( $mxml_threshold_configfile );

    my @queue_tasktypes = ();
    my $ref = $mxml_threshold_config->retrieve( 'MXML_THRESHOLDS.queue_tasktype', 1 );
    if ( $ref ) {
      if ( ref($ref) eq 'ARRAY' ) {
          @queue_tasktypes = @{$ref};
      }
      else {
          @queue_tasktypes = ( $ref );
      }
    }

    @QUEUE_TASKTYPES = @queue_tasktypes;

    return @QUEUE_TASKTYPES;
}

#----------------------#
sub message_throughput {
#----------------------#
    my ( $class, %args ) = @_;


    if ( $MESSAGE_THROUGHPUT ) {
        return $MESSAGE_THROUGHPUT;
    }

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $mxml_threshold_configfile = $config->retrieve('MXML_THRESHOLDSFILE');
    my $mxml_threshold_config     = Mx::Config->new( $mxml_threshold_configfile );

    $MESSAGE_THROUGHPUT = $mxml_threshold_config->retrieve( 'MXML_THRESHOLDS.message_throughput', 1 );

    return $MESSAGE_THROUGHPUT;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

1;
