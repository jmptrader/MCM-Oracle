package Mx::MxML::Message;
 
use strict;
use Carp;

use IO::String;
#use Archive::Zip;
 
#
# Properties:
#
# reference_id
# timestamp
# status_timestamp
# wait_time
# proc_time
# key_id
# node_id
# fc_id
# fc_family
# fc_group
# fc_type
# fc_package_id
# archived
#

our %WORKFLOWS = (
  Contract    => 'FC',
  Deliverable => 'DLV',
  Event       => 'EVT',
  Exchange    => 'DOC',
  SI          => 'SI'
);

my %KEYFIELDS = (
  Contract    => 'FC_ID',
  Deliverable => 'DLV_FLOW_ID',
  Event       => 'EVT_ID',
  Exchange    => 'DOC_ID',
  SI          => 'SI_ID'
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
        $logger->logdie("missing argument in initialisation of MxML message (config)");
    }
    $self->{config} = $config;
 
    $self->{reference_id}     = $args{reference_id};
    $self->{timestamp}        = $args{timestamp};
    $self->{status_timestamp} = $args{status_timestamp};
    $self->{wait_time}        = $args{wait_time};
    $self->{proc_time}        = $args{proc_time};
    $self->{status_taken}     = $args{status_taken};
    $self->{workflow}         = $args{workflow};
    $self->{key_id}           = $args{key_id};
    $self->{node_id}          = $args{node_id};
    $self->{fc_id}            = $args{fc_id};
    $self->{fc_family}        = $args{fc_family};
    $self->{fc_group}         = $args{fc_group};
    $self->{fc_type}          = $args{fc_type};
    $self->{fc_package_id}    = $args{fc_package_id};
    $self->{archived}         = $args{archived};
 
    bless $self, $class;
}

#----------------#
sub retrieve_all {
#----------------#
    my ($class, %args) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined';

    #
    # check the arguments
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (library)");
    }

    my $task;
    unless ( $task = $args{task} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (task)");
    }

    my $nodelist = join ',', map { "'" . $_->id . "'" } $task->source_nodes;

    my $fromdate;
    unless ( $fromdate = $args{fromdate} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (fromdate)");
    }

    my $todate;
    unless ( $todate = $args{todate} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (todate)");
    }

    my $status_taken;
    unless ( $status_taken = $args{status_taken} ) {
        $logger->logdie("missing argument in retrieval of MxML messages (status_taken)");
    }

    my $archived = ( $args{archived} ) ? 1 : 0;

    my $query = $library->query('retrieve_mxml_messages');

    my $workflow = $task->workflow;

    my $workflow_string = $WORKFLOWS{ $workflow };
    my $keyfield        = $KEYFIELDS{ $workflow };

    $query =~ s/__WORKFLOW__/$workflow_string/;
    $query =~ s/__KEYFIELD__/$keyfield/;
    $query =~ s/__NODELIST__/$nodelist/;

    if ( $status_taken eq 'Y' or $status_taken eq 'N' ) {
        $query .= " and STATUS_TAKEN = '$status_taken'";
    }
 
    my $result = $oracle->query( query => $query, values => [ $fromdate, $todate ] );

    my @list;
    while ( my ($reference_id, $timestamp, $status_timestamp, $wait_time, $proc_time, $status_taken, $key_id, $node_id, $fc_id, $fc_family, $fc_group, $fc_type, $fc_package_id) = $result->next ) {

        push @list, Mx::MxML::Message->new(
          reference_id     => $reference_id,
          timestamp        => $timestamp,
          status_timestamp => $status_timestamp,
          wait_time        => $wait_time,
          proc_time        => $proc_time,
          status_taken     => $status_taken,
          workflow         => $workflow,
          key_id           => $key_id,
          node_id          => $node_id,
          fc_id            => $fc_id,
          fc_family        => $fc_family,
          fc_group         => $fc_group,
          fc_type          => $fc_type,
          fc_package_id    => $fc_package_id,
          archived         => $archived,
          logger           => $logger,
          config           => $config
        );
    }

    return @list;
}

#--------------------#
sub retrieve_details {
#--------------------#
    my ($class, %args) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in retrieval of MxML details (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in retrieval of MxML details (library)");
    }

    my $reference_id;
    unless ( $reference_id = $args{reference_id} ) {
        $logger->logdie("missing argument in retrieval of MxML details (reference_id)");
    }

    my $workflow;
    unless ( $workflow = $args{workflow} ) {
        $logger->logdie("missing argument in retrieval of MxML route (workflow)");
    }

    my $query = $library->query('retrieve_mxml_message_details');

    my $workflow_string = $WORKFLOWS{ $workflow };
    my $keyfield = $KEYFIELDS{ $workflow };
    $query =~ s/__WORKFLOW__/$workflow_string/;

    my $result = $oracle->query( query => $query, values => [ $reference_id ] );

    return ( $result->nextref , [ $result->columns ] );
}

#------------------#
sub retrieve_route {
#------------------#
    my ($class, %args) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in retrieval of MxML route (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in retrieval of MxML route (library)");
    }

    my $key_id;
    unless ( $key_id = $args{key_id} ) {
        $logger->logdie("missing argument in retrieval of MxML route (key_id)");
    }

    my $workflow;
    unless ( $workflow = $args{workflow} ) {
        $logger->logdie("missing argument in retrieval of MxML route (workflow)");
    }

    my $nodes;
    unless ( $nodes = $args{nodes} ) {
        $logger->logdie("missing argument in retrieval of MxML route (nodes)");
    }

    my $archived = ( $args{archived} ) ? 1 : 0;

    my $query = $library->query('retrieve_mxml_route');

    my $workflow_string = $WORKFLOWS{ $workflow };
    my $keyfield        = $KEYFIELDS{ $workflow };
    my $field           = $args{key} || $keyfield;
    $query =~ s/__KEYFIELD__/$keyfield/;
    $query =~ s/__FIELD__/$field/;
    $query =~ s/__WORKFLOW__/$workflow_string/;

    my $result = $oracle->query( query => $query, values => [ $key_id ] );

    my @list;
    while ( my ($reference_id, $timestamp, $status_timestamp, $wait_time, $proc_time, $status_taken, $node_id, $key_id, $fc_id ) = $result->next ) {
        my $nodename = ''; my $tasktype = '';
        if ( my $node = $nodes->{ $node_id } ) {
            $nodename = $node->taskname . ':' . $node->nodename;
            $tasktype = $node->tasktype;
        }
    
        push @list, {
          0  => $reference_id,
          1  => Mx::Util->convert_time( $timestamp / 1000 ),
          2  => $timestamp,
          3  => Mx::Util->convert_time( $status_timestamp / 1000 ),
          4  => $status_timestamp,
          5  => Mx::Util->separate_thousands( $wait_time ),
          6  => Mx::Util->separate_thousands( $proc_time ),
          7  => $status_taken,
          8  => $nodename,
          9  => $tasktype,
          10 => $key_id,
          11 => $fc_id,
          12 => 0,
          13 => ( $archived ) ? 'YES' : 'NO',
          DT_RowId => $reference_id . '.' . $workflow . '.' . $key_id . '.' . $archived
        }
    }

    return @list;
}

#-------------------#
sub retrieve_bodies {
#-------------------#
    my ($class, %args) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in retrieval of MxML bodies (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in retrieval of MxML bodies (library)");
    }

    my $reference_id;
    unless ( $reference_id = $args{reference_id} ) {
        $logger->logdie("missing argument in retrieval of MxML bodies (reference_id)");
    }

    my $workflow;
    unless ( $workflow = $args{workflow} ) {
        $logger->logdie("missing argument in retrieval of MxML route (workflow)");
    }

    my $query = $library->query('retrieve_mxml_bodies');

    my $workflow_string = $WORKFLOWS{ $workflow };
    $query =~ s/__WORKFLOW__/$workflow_string/;

    my $result = $oracle->query( query => $query, values => [ $reference_id ] );

    my @list;
    while ( my ($body_id, $date, $time, $grammar, $io, $version, $version_last, $content_type, $size) = $result->next ) {
        push @list, {
          0  => $body_id,
          1  => $date . ' ' . $time,
          2  => $grammar,
          3  => $io,
          4  => $version,
          5  => $version_last,
          6  => $content_type,
          7  => Mx::Util->separate_thousands( $size ),
          DT_RowId => $body_id
        }
    }

    return @list;
}

#-----------------#
sub retrieve_body {
#-----------------#
    my ($class, %args) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in retrieval of MxML body (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in retrieval of MxML body (library)");
    }

    my $body_id;
    unless ( $body_id = $args{body_id} ) {
        $logger->logdie("missing argument in retrieval of MxML body (body_id)");
    }

    my $query = $library->query('retrieve_mxml_body');

	my $result = $oracle->query( query => $query, values => [ $body_id ] );

	my ( $compressed, $xml ) = $result->next;

    my $length = length( $xml );

    $logger->debug("retrieve_body: compressed size: $compressed - query size: $length");

    if ( $compressed ) {
        my $fh  = IO::String->new( $xml );
        my $zip = Archive::Zip->new();
        $zip->readFromFileHandle( $fh );
        my ( $member ) = $zip->members();
        $xml = $zip->contents( $member );
    }

    return $xml;
}

#----------------#
sub reference_id {
#----------------#
    my ( $self ) = @_;
 
 
    return $self->{reference_id};
}

#----------------#
sub status_taken {
#----------------#
    my ( $self ) = @_;
 
 
    return $self->{status_taken};
}

#-------------#
sub timestamp {
#-------------#
    my ( $self ) = @_;
 
 
    return $self->{timestamp};
}

#-------------#
sub proc_time {
#-------------#
    my ( $self ) = @_;
 
 
    return $self->{proc_time};
}

#-------------#
sub wait_time {
#-------------#
    my ( $self ) = @_;
 
 
    return $self->{wait_time};
}

#--------------------#
sub status_timestamp {
#--------------------#
    my ( $self ) = @_;
 
 
    return $self->{status_timestamp};
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

#------------#
sub archived {
#------------#
    my ( $self ) = @_;


    return $self->{archived};
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;

    return {
      0  => $self->{reference_id},
      1  => Mx::Util->convert_time( $self->{timestamp} / 1000 ),
      2  => $self->{timestamp},
      3  => Mx::Util->convert_time( $self->{status_timestamp} / 1000 ),
      4  => $self->{status_timestamp},
      5  => Mx::Util->separate_thousands( $self->{wait_time} ),
      6  => Mx::Util->separate_thousands( $self->{proc_time} ),
      7  => $self->{status_taken},
      8  => $self->{key_id},
      9  => $self->{node_id},
      10 => $self->{fc_id},
      11 => $self->{fc_family},
      12 => $self->{fc_group},
      13 => $self->{fc_type},
      14 => $self->{fc_package_id},
      15 => ( $self->{archived} ) ? 'YES' : 'NO',
      DT_RowId => $self->{reference_id} . '.' . $self->{workflow} . '.' . $self->{key_id} . '.' . $self->{fc_id} . '.' . $self->{archived}
    };
}

1;
