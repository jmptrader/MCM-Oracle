package Mx::MxML::Task;

use strict;

use Mx::Log;
use Mx::Config;
use Mx::Alert;
use Carp;

#
# Properties:
#
# taskname
# tasktype
# sheetname
# workflow
# nr_messages
# mtime
# nr_messages_warn
# nr_messages_fail
# timeout_warn
# timeout_fail
# oldest_timestamp
# warning_address
# fail_address
#

my %QUEUE_TASKTYPES = ();

our %WORKFLOWS = (
  Contract    => 'FC',
  Deliverable => 'DLV',
  Event       => 'EVT',
  Exchange    => 'DOC',
  SI          => 'SI'
);

our $STATUS_UNKNOWN = 'unknown';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;
 
 
    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;
 
    #
    # check the arguments
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of MxML task (config)");
    }
    $self->{config} = $config;
 
    $self->{taskname}         = $args{taskname};
    $self->{tasktype}         = $args{tasktype};
    $self->{sheetname}        = $args{sheetname};
    $self->{workflow}         = $args{workflow};
    $self->{source_nodes}     = [];
    $self->{nr_messages}      = 0;
    $self->{mtime}            = time();
    $self->{oldest_timestamp} = time();
    $self->{nr_messages_warn} = -1;
    $self->{nr_messages_fail} = -1;
    $self->{timeout_warn}     = -1;
    $self->{timeout_fail}     = -1;
    $self->{warning_address}  = undef;
    $self->{fail_address}     = undef;
 
    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    my $taskname;
    unless ( $taskname = $args{taskname} ) {
        $logger->logdie("missing argument (taskname)");
    }

    my $result;
    unless ( $result = $db_audit->retrieve_mxml_task( taskname => $taskname ) ) {
        $logger->error("no MxML task with as taskname '$taskname' found");
        return;
    }

    return Mx::MxML::Task->new(
      logger           => $logger,
      config           => $config,
      taskname         => $result->[0],
      tasktype         => $result->[1],
      sheetname        => $result->[2],
      workflow         => $result->[3],
    );
}

#-------------------#
sub add_source_node {
#-------------------#
    my ( $self, $node ) = @_;


    push @{$self->{source_nodes}}, $node;
}

#--------------------#
sub apply_thresholds {
#--------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    $logger->debug("applying thresholds");

    my $tasks;
    unless ( $tasks = $args{tasks} ) {
        $logger->logdie("missing argument (tasks)");
    }

    my $thresholds;
    unless ( $thresholds = $args{thresholds} ) {
        $logger->logdie("missing argument (thresholds)");
    }

    foreach my $threshold ( @{$thresholds} ) {
        my $name = $threshold->name;

        $logger->debug("applying threshold '$name'");
        
        foreach my $task ( values %{$tasks} ) {
            $threshold->apply( task => $task );
        }
    }
}

#--------------------#
sub check_thresholds {
#--------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    $logger->debug("checking thresholds");

    my $tasks;
    unless ( $tasks = $args{tasks} ) {
        $logger->logdie("missing argument (tasks)");
    }

    my $size_alert;
    unless ( $size_alert = $args{size_alert} ) {
        $logger->logdie("missing argument (size_alert)");
    }

    my $timeout_alert;
    unless ( $timeout_alert = $args{timeout_alert} ) {
        $logger->logdie("missing argument (timeout_alert)");
    }

    my $currenttime = time();

    foreach my $task ( values %{$tasks} ) {
        my $nr_messages      = $task->{nr_messages} or next;
        my $taskname         = $task->{taskname};

        my $nr_messages_warn = $task->{nr_messages_warn};
        my $nr_messages_fail = $task->{nr_messages_fail};

        if ( $nr_messages_warn != -1 and $nr_messages >= $nr_messages_warn and ( $nr_messages < $nr_messages_fail or $nr_messages_fail == -1 ) ) {
            $size_alert->set_warning_address( $task->{warning_address} ) if $task->{warning_address};
            $size_alert->trigger( item => $taskname, values => [ $nr_messages ], level => $Mx::Alert::LEVEL_WARNING );
        }
        elsif ( $nr_messages_fail != -1 and $nr_messages >= $nr_messages_fail ) {
            $size_alert->set_fail_address( $task->{fail_address} ) if $task->{fail_address};
            $size_alert->trigger( item => $taskname, values => [ $nr_messages ], level => $Mx::Alert::LEVEL_FAIL );
        }

        my $timeout_warn = $task->{timeout_warn};
        my $timeout_fail = $task->{timeout_fail};
        my $timeout      = $currenttime - $task->{mtime};

        if ( $timeout_warn != -1 and $timeout >= $timeout_warn and ( $timeout < $timeout_fail or $timeout_fail == -1 ) ) {
            $timeout_alert->set_warning_address( $task->{warning_address} ) if $task->{warning_address};
            $timeout_alert->trigger( item => $taskname, values => [ $timeout ], level => $Mx::Alert::LEVEL_WARNING );
        }
        elsif ( $timeout_fail != -1 and $timeout >= $timeout_fail ) {
            $timeout_alert->set_fail_address( $task->{fail_address} ) if $task->{fail_address};
            $timeout_alert->trigger( item => $taskname, values => [ $timeout ], level => $Mx::Alert::LEVEL_FAIL );
        }
    }

    $logger->debug("thresholds checked");
}

#---------------------#
sub is_queue_tasktype {
#---------------------#
    my ( $self ) = @_;


    unless ( %QUEUE_TASKTYPES ) {
        my @queue_tasktypes = Mx::MxML::Threshold->queue_tasktypes( config => $self->{config}, logger => $self->{logger} );
        foreach ( @queue_tasktypes ) {
            $QUEUE_TASKTYPES{ $_ } = 1;
        }
    }

    my $tasktype = $self->{tasktype};

    return $QUEUE_TASKTYPES{ $tasktype };
}

#------------#
sub taskname {
#------------#
    my ( $self ) = @_;


    return $self->{taskname};
}

#------------#
sub tasktype {
#------------#
    my ( $self ) = @_;


    return $self->{tasktype};
}

#-------------#
sub sheetname {
#-------------#
    my ( $self ) = @_;


    return $self->{sheetname};
}

#------------#
sub workflow {
#------------#
    my ( $self ) = @_;


    return $self->{workflow};
}

#------------------#
sub workflow_short {
#------------------#
    my ( $self ) = @_;


    return $WORKFLOWS{ $self->{workflow} };
}

#---------------#
sub nr_messages {
#---------------#
    my ( $self ) = @_;


    return $self->{nr_messages};
}

#----------------#
sub source_nodes {
#----------------#
    my ( $self ) = @_;


    return @{$self->{source_nodes}};
}

#--------------------#
sub nr_messages_warn {
#--------------------#
    my ( $self ) = @_;


    return $self->{nr_messages_warn};
}

#--------------------#
sub nr_messages_fail {
#--------------------#
    my ( $self ) = @_;


    return $self->{nr_messages_fail};
}

#----------------#
sub timeout_warn {
#----------------#
    my ( $self ) = @_;


    return $self->{timeout_warn};
}

#----------------#
sub timeout_fail {
#----------------#
    my ( $self ) = @_;


    return $self->{timeout_fail};
}

#-------------------#
sub warning_address {
#-------------------#
    my ( $self ) = @_;


    return $self->{warning_address};
}

#----------------#
sub fail_address {
#----------------#
    my ( $self ) = @_;


    return $self->{fail_address};
}

#-------------------------#
sub increment_nr_messages {
#-------------------------#
    my ( $self, $increment ) = @_;


    $self->{nr_messages} += $increment if $increment;
}

#---------------------------#
sub update_oldest_timestamp {
#---------------------------#
    my ( $self, $timestamp ) = @_;


    $self->{oldest_timestamp} = $timestamp if $timestamp < $self->{oldest_timestamp};
}

#---------------------#
sub reset_nr_messages {
#---------------------#
    my ( $self ) = @_;


    $self->{nr_messages} = 0;
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;

    return {
      0  => $self->{nr_messages_warn},
      1  => $self->{nr_messages_fail},
      2  => $self->{timeout_warn},
      3  => $self->{timeout_fail},
      4  => $self->{warning_address},
      5  => $self->{fail_address}
    };
}

1;
