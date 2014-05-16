package Mx::MxML::Node;

use strict;

use Mx::MxML::Task;
use Mx::MxML::Threshold;
use Carp;

#
# Properties:
#
# id:                    unique id of the node
# nodename:              name of the node
# in_out:                input or output node
# taskname
# sheetname
# workflow
# msg_taken_y
# msg_taken_n
# prev_msg_taken_y
# prev_msg_taken_n
# oldest_timestamp
#

our %WORKFLOWS = (
  Contract    => 'FC',
  Deliverable => 'DLV',
  Event       => 'EVT',
  Exchange    => 'DOC',
  SI          => 'SI'
);

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
        $logger->logdie("missing argument in initialisation of MxML node (config)");
    }
    $self->{config} = $config;

    $self->{id}               = $args{id};
    $self->{nodename}         = $args{nodename};
    $self->{in_out}           = $args{in_out};
    $self->{taskname}         = $args{taskname};
    $self->{tasktype}         = $args{tasktype};
    $self->{sheetname}        = $args{sheetname};
    $self->{workflow}         = $args{workflow};
    $self->{target_tasks}     = $args{target_tasks};
    $self->{msg_taken_y}      = $args{msg_taken_y};
    $self->{msg_taken_n}      = $args{msg_taken_n};
    $self->{proc_time}        = $args{proc_time};
    $self->{prev_msg_taken_y} = -1;
    $self->{prev_msg_taken_n} = -1;
 
    bless $self, $class;
}


#----------------#
sub retrieve_all {
#----------------#
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

    my %include = ();
    if ( $args{exclude} ) {
        my $includefile = $config->MXML_INCLUDEFILE;
        my $include_config = Mx::Config->new( $includefile );
        my $taskref = $include_config->TASK;
        foreach my $task ( @{$taskref} ) {
            $include{ $task } = 1;
            $logger->debug("including task $task");
        }
    }

    my @rows = $db_audit->retrieve_mxml_nodes();

    my %nodes = (); my %tasks = ();

    foreach my $row ( @rows ) {
        my $id = $row->[0]; my $target_task = $row->[7];

        $id =~ s/\s+$//;

        my @target_tasks;
        if ( $target_task ) {
            @target_tasks = ( $target_task );
        }
        else {
            @target_tasks = $db_audit->retrieve_mxml_links( id => $id );
        }

        my $node = Mx::MxML::Node->new(
          logger           => $logger,
          config           => $config,
          id               => $id,
          nodename         => $row->[1],
          in_out           => $row->[2],
          taskname         => $row->[3],
          tasktype         => $row->[4],
          sheetname        => $row->[5],
          workflow         => $row->[6],
          target_tasks     => \@target_tasks,
          msg_taken_y      => $row->[8],
          msg_taken_n      => $row->[9],
          proc_time        => $row->[10],
        );

        my $taskname = $node->{taskname};
        unless ( $tasks{$taskname} ) {
            $tasks{$taskname} = Mx::MxML::Task->new( taskname => $taskname, tasktype => $node->{tasktype}, sheetname => $node->{sheetname}, workflow => $node->{workflow}, logger => $logger, config => $config );
        }

        $nodes{ $id } = $node;
    }

    foreach my $node ( values %nodes ) {
        my @target_task_names = @{$node->{target_tasks}};

        my @target_tasks = ();
        foreach my $target_task_name ( @target_task_names ) {
            my $target_task = $tasks{$target_task_name};
            push @target_tasks, $target_task;
            $target_task->increment_nr_messages( $node->{msg_taken_n} ) unless $args{exclude};
            $target_task->add_source_node( $node );
        }

        $node->{target_tasks} = \@target_tasks;

        $node->{own_task} = $tasks{ $node->{taskname} };
    }

    if ( $args{exclude} ) {
        my %new_nodes = ();
        foreach my $node ( values %nodes ) {
            my $id = $node->{id};
            foreach my $target_task ( @{$node->{target_tasks}} ) {
                my $taskname = $target_task->taskname or next;
                if ( $target_task->is_queue_tasktype ) {
                    if ( $include{ $taskname } ) {
                        $new_nodes{ $id } = $node;
                    } 
                }
                else {
                    $new_nodes{ $id } = $node;
                }
            }
        }
        return ( \%new_nodes, \%tasks );
    }
    else { 
        return ( \%nodes, \%tasks );
    }
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

    my $result;
    if ( my $taskname = $args{taskname} and my $nodename = $args{nodename} ) {
        unless ( $result = $db_audit->retrieve_mxml_node( taskname => $taskname, nodename => $nodename ) ) {
            $logger->error("no MxML node with as taskname '$taskname' and as nodename '$nodename' found");
            return;
        }
    }
    elsif ( my $id = $args{id} ) {
        unless ( $result = $db_audit->retrieve_mxml_node( id => $id ) ) {
            $logger->error("no MxML node with id $id found");
            return;
        }
    }
    else {
        $logger->logdie("missing argument (taskname, nodename or id)");
    }

    my $id = $result->[0]; my $target_task = $result->[7];

    $id =~ s/\s+$//;

    my @target_tasks;
    if ( $target_task ) {
        @target_tasks = ( $target_task );
    }
    else {
        @target_tasks = $db_audit->retrieve_mxml_links( id => $id );
    }

    my $node = Mx::MxML::Node->new(
      logger           => $logger,
      config           => $config,
      id               => $result->[0],
      nodename         => $result->[1],
      in_out           => $result->[2],
      taskname         => $result->[3],
      tasktype         => $result->[4],
      sheetname        => $result->[5],
      workflow         => $result->[6],
      target_tasks     => \@target_tasks,
      msg_taken_y      => $result->[8],
      msg_taken_n      => $result->[9],
      proc_time        => $result->[10]
    );

    my @target_task_names = @{$node->{target_tasks}};

    my @target_tasks = ();
    foreach my $target_task_name ( @target_task_names ) {
        push @target_tasks, Mx::MxML::Task->retrieve( taskname => $target_task_name, db_audit => $db_audit, config => $config, logger => $logger ) if $target_task_name;
    }

    $node->{target_tasks} = \@target_tasks;

    $node->{own_task} = Mx::MxML::Task->retrieve( taskname => $node->{taskname}, db_audit => $db_audit, config => $config, logger => $logger ) if $node->{taskname};

    return $node;
}


#----------------------#
sub update_nr_messages {
#----------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $date = $args{date};

    my $orig_query = ( $date ) ? $library->query('mxml_nr_messages_per_day') : $library->query('mxml_nr_messages');

    foreach my $node ( values %{$nodes} ) {
        map { $_->reset_nr_messages() } @{$node->{target_tasks}}; 
    }

    my $prev_workflow_string = ''; my $query;
    foreach my $node ( sort { $a->{workflow} cmp $b->{workflow} } values %{$nodes} ) {
        my $id       = $node->{id};
        my $workflow = $node->{workflow};
        my $workflow_string = $WORKFLOWS{$workflow};
        my @target_tasks = @{$node->{target_tasks}};

        if ( $workflow_string ne $prev_workflow_string ) {
            $prev_workflow_string = $workflow_string;
            $query = $orig_query;
            $query =~ s/__WORKFLOW__/$workflow_string/; 
            $logger->debug("doing workflow '$workflow_string'");
        }

        my $result;
        my $values = ( $date ) ? [ $id, 'N', $date ] : [ $id, 'N' ];
        $result = $oracle->query( query => $query, values => $values, quiet => 1 );
        ( $node->{msg_taken_n}, $node->{oldest_timestamp} ) = $result->next;

        foreach my $target_task ( @target_tasks ) {
            $target_task->increment_nr_messages( $node->{msg_taken_n} );
            $target_task->update_oldest_timestamp( $node->{oldest_timestamp} );
        }

        if ( $args{only_untaken} ) {
            $node->{msg_taken_y} = -1;
        }
        else {
            $values = ( $date ) ? [ $id, 'Y', $date ] : [ $id, 'Y' ];
            $result = $oracle->query( query => $query, values => $values, quiet => 1 );
            $node->{msg_taken_y} = $result->nextref->[0];
        }
    }

    $logger->debug("retrieved all message counts");
}

#-----------------------#
sub refresh_nr_messages {
#-----------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    foreach my $row ( $db_audit->retrieve_mxml_nr_messages2() ) {
        if ( my $node = $nodes->{ $row->[0] } ) {
            $node->{msg_taken_y} = $row->[1];
            $node->{msg_taken_n} = $row->[2];
            $node->{proc_time}   = $row->[3];
        }
    }
}

#--------------------#
sub update_proc_time {
#--------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $orig_query  = $library->query('mxml_proc_time');

    my $prev_workflow_string = ''; my $query;
    foreach my $node ( sort { $a->{workflow} cmp $b->{workflow} } values %{$nodes} ) {
        my $id       = $node->{id};
        my $workflow = $node->{workflow};
        my $workflow_string = $WORKFLOWS{$workflow};

        if ( $workflow_string ne $prev_workflow_string ) {
            $prev_workflow_string = $workflow_string;
            $query = $orig_query;
            $query =~ s/__WORKFLOW__/$workflow_string/; 
            $logger->debug("doing workflow '$workflow_string'");
        }

        my $result;
        $result = $oracle->query( query => $query, values => [ $id, 'Y' ], quiet => 1 );
        $node->{proc_time} = ($result->next)[0];
    }

    $logger->debug("retrieved all proc times");
}

#------------------------#
sub retrieve_nr_messages {
#------------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $id     = $self->{id};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    my $begin_timestamp;
    unless ( $begin_timestamp = $args{begin_timestamp} ) {
        $logger->logdie("missing argument (begin_timestamp)");
    }

    my $end_timestamp;
    unless ( $end_timestamp = $args{end_timestamp} ) {
        $logger->logdie("missing argument (end_timestamp)");
    }

    my @results = $db_audit->retrieve_mxml_nr_messages( id => $id, begin_timestamp => $begin_timestamp, end_timestamp => $end_timestamp );

    my %nr_messages = ();
    foreach my $result ( @results ) {
        my $timestamp   = $result->[0];
        my $nr_messages = $result->[1];
        $nr_messages{ $timestamp } = $nr_messages;
    }

    return %nr_messages;
}

#---------#
sub audit {
#---------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    foreach my $node ( values %{$nodes} ) {
        if ( $node->{msg_taken_y} == -1 ) {
            $db_audit->update_mxml_node( id => $node->{id}, msg_taken_n => $node->{msg_taken_n}, proc_time => $node->{proc_time} );
        }
        else {
            $db_audit->update_mxml_node( id => $node->{id}, msg_taken_y => $node->{msg_taken_y}, msg_taken_n => $node->{msg_taken_n}, proc_time => $node->{proc_time} );
        }
    }
}

#--------------#
sub hist_audit {
#--------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    my $timestamp = time();

    $db_audit->update_mxml_node_hist( id => 0, timestamp => $timestamp, msg_taken_n => 0 );

    foreach my $node ( values %{$nodes} ) {
        if ( $node->{msg_taken_n} != $node->{prev_msg_taken_n} ) {
            $db_audit->update_mxml_node_hist( id => $node->{id}, timestamp => $timestamp, msg_taken_n => $node->{msg_taken_n} );
       
            $node->{prev_msg_taken_n} = $node->{msg_taken_n};
        }
    }
}

#--------------------#
sub check_thresholds {
#--------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument (nodes)");
    }

    my $threshold;
    unless ( $threshold = $args{threshold} ) {
        $logger->logdie("missing argument (threshold)");
    }

    my $interval;
    unless ( $interval = $args{interval} ) {
        $logger->logdie("missing argument (interval)");
    }

    my $alert;
    unless ( $alert = $args{alert} ) {
        $logger->logdie("missing argument (alert)");
    }

    foreach my $node ( values %{$nodes} ) {
        if ( $node->{prev_msg_taken_y} != -1 ) {
            my $throughput = ( $node->{msg_taken_y} - $node->{prev_msg_taken_y} ) / $interval;

            if ( $throughput > $threshold ) {
                $alert->trigger( item => $node->{taskname}, values => [ $throughput, $node->{nodename} ], level => $Mx::Alert::LEVEL_WARNING );
            }
        }

        $node->{prev_msg_taken_y} = $node->{msg_taken_y};
    }
}

#----------------#
sub zombie_nodes {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $orig_query  = $library->query('mxml_lost_messages');

    my $mondb_name  = $config->retrieve('MONDB_NAME');

    my %nodes = ();
    while ( my( $workflow, $workflow_string ) = each %WORKFLOWS ) {
        my $query = $orig_query;
        $query =~ s/__WORKFLOW__/$workflow_string/;
        $query =~ s/__MONDB_NAME__/$mondb_name/;

        my $result = $oracle->query( query => $query );

        while ( my ( $nr_messages, $id, $status_taken ) = $result->next ) {
            my $msg_taken_y = 0; my $msg_taken_n = 0;
            if ( $status_taken eq 'Y' ) {
                $msg_taken_y = $nr_messages;
            }
            else {
                $msg_taken_n = $nr_messages;
            }

            if ( my $node = $nodes{$id} ) {
                if ( $msg_taken_y ) {
                    $node->{msg_taken_y} = $msg_taken_y;
                }
                else {
                    $node->{msg_taken_n} = $msg_taken_n;
                }
            }
            else {
                my $node = Mx::MxML::Node->new(
                  id          => $id,
                  workflow    => $workflow,
                  msg_taken_y => $msg_taken_y,
                  msg_taken_n => $msg_taken_n,
                  logger      => $logger,
                  config      => $config
                );

                $nodes{$id} = $node;
            }
        }
    }

    return values %nodes;
}

#------#
sub id {
#------#
    my ( $self ) = @_;


    return $self->{id};
}

#------------#
sub nodename {
#------------#
    my ( $self ) = @_;


    return $self->{nodename};
}

#----------#
sub in_out {
#----------#
    my ( $self ) = @_;


    return $self->{in_out};
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

#----------------#
sub target_tasks {
#----------------#
    my ( $self ) = @_;


    return @{$self->{target_tasks}};
}

#---------------#
sub msg_taken_y {
#---------------#
    my ( $self ) = @_;


    return $self->{msg_taken_y};
}

#---------------#
sub msg_taken_n {
#---------------#
    my ( $self ) = @_;


    return $self->{msg_taken_n};
}

#--------------------#
sub oldest_timestamp {
#--------------------#
    my ( $self ) = @_;


    return $self->{oldest_timestamp};
}

#-------------#
sub proc_time {
#-------------#
    my ( $self ) = @_;


    return $self->{proc_time};
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;

    my @target_task_names = map { $_->{taskname} } @{$self->{target_tasks}}; 
    my @target_task_types = map { $_->{tasktype} } @{$self->{target_tasks}};

    return {
      0  => $self->{workflow},
      1  => $self->{sheetname},
      2  => $self->{taskname},
      3  => $self->{tasktype},
      4  => Mx::Util->separate_thousands( $self->{own_task}->nr_messages ),
      5  => $self->{in_out},
      6  => $self->{nodename},
      7  => $self->{id},
      8  => Mx::Util->separate_thousands( $self->{msg_taken_y} ) || 0,
      9  => Mx::Util->separate_thousands( $self->{msg_taken_n} ) || 0,
      10 => ( join '<br>', @target_task_names ),
      11 => ( join '<br>', @target_task_types ),
      DT_RowId => $self->{taskname}
    };
}

1;
