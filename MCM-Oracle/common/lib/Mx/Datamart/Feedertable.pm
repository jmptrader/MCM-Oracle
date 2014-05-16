package Mx::Datamart::Feedertable;

use strict;
use warnings;

use Mx::Datamart::Feeder;
use Carp;

#
# Properties:
#
# $id
# $name
# $feeder
# $job_id
# $ref_data
# $nr_records
#

our $TYPE_DYNAMIC    = 'dynamic';
our $TYPE_DYNAMIC_CC = 'dynamic_cc';
our $TYPE_SQL        = 'sql';
our $TYPE_UNKNOWN    = 'unknown';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $id         = $self->{id}         = $args{id};
    my $name       = $self->{name}       = $args{name};
    my $feeder     = $self->{feeder}     = $args{feeder};
    my $logger     = $self->{logger}     = $args{logger};
    my $config     = $self->{config}     = $args{config};
    my $oracle     = $self->{oracle}     = $args{oracle};
    my $oracle_rep = $self->{oracle_rep} = $args{oracle_rep};
    my $library    = $self->{library}    = $args{library};

    my $type = $args{type};
    if ( $type == 0 or $type == 8 ) {
        $type = $self->{type} = $TYPE_DYNAMIC;
    }
    elsif ( $type == 2 ) {
        $type = $self->{type} = $TYPE_DYNAMIC_CC;
    }
    elsif ( $type == 4 ) {
        $type = $self->{type} = $TYPE_SQL;
    }
    else {
        $type = $self->{type} = $TYPE_UNKNOWN;
    } 

    $logger->info("table $name identified (id: $id - type: $type)");

    $self->{job_id}     = undef;
    $self->{ref_data}   = undef;
    $self->{nr_records} = 0;

    bless $self, $class;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @tables;

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of feedertable (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of feedertable (oracle)");
    }

    my $oracle_rep;
    unless ( $oracle_rep = $args{oracle_rep} ) {
        $logger->logdie("missing argument in initialisation of feedertable (oracle_rep)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in initialisation of feedertable (library)");
    }

    my $feeder;
    unless ( $feeder = $args{feeder} ) {
        $logger->logdie("missing argument in initialisation of feedertable (feeder)");
    }

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in initialisation of feedertable (semaphore)");
    }

    my $query;
    unless ( $query = $library->query('get_feeder_tables') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'get_feeder_tables' cannot be retrieved from the library");
    }

    my $feederid   = $feeder->id;
    my $feedername = $feeder->name;

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $feederid ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve tables for feeder $feedername");
    }

    unless ( $query = $library->query('get_dyntable_type') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'get_dyntable_type' cannot be retrieved from the library");
    }

    my $additional_query;
    unless ( $additional_query = $library->query('get_additional_dyntable_type') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'get_additional_dyntable_type' cannot be retrieved from the library");
    }

    while ( my ( $id, $name, $type, $reference ) = $result->next ) {
        if ( $type == 0 ) {
            my @rows;
            my $result2 = $oracle->query( query => $query, values => [ $reference ] );
            unless ( @rows = $result2->all_rows ) {
                my $result3 = $oracle->query( query => $additional_query, values => [ $reference ] );
                unless ( @rows = $result3->all_rows ) {
                    $semaphore->release();
                    $logger->logdie("cannot retrieve dynamic table type for feedertable $name");
                }
            }

            $type = $rows[0][0];
        }

        push @tables, Mx::Datamart::Feedertable->new( id => $id, name => $name, type => $type, feeder => $feeder, library => $library, oracle => $oracle, oracle_rep => $oracle_rep, config => $config, logger => $logger );
    }

    return @tables;
}

#---------------#
sub update_name {
#---------------#
    my ( $self , %args ) = @_;


    my $logger  = $self->{logger};
    my $library = $self->{library};
    my $oracle  = $self->{oracle};
    my $name    = $self->{name};
    my $id      = $self->{id};
    my $feeder  = $self->{feeder};

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument in update_name (entity)");
    }

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in update_name (semaphore)");
    }

    my $current_entity = substr( $name, 1, 2 );

    if ( $current_entity eq 'XX' or ! Mx::Scheduler->entity_short2long( $current_entity ) ) {
        $logger->debug("feedertable $name contains $current_entity, no substitution allowed");

        return;
    }
    elsif ( $current_entity eq $entity ) {
        $logger->debug("feedertable $name already contains $entity, no substitution necessary");

        return;
    }
    else {
        substr( $name, 1, 2 ) = $entity;

        $self->{name} = $name;
    }

    my $query;
    unless ( $query = $library->query('check_feeder_table') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'check_feeder_table' cannot be retrieved from the library");
    }

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $name ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot determine existing tables");
    }
 
    unless ( $result->nextref->[0] == 1 ) {
        $semaphore->release();
        $logger->logdie("cannot find a table with as name $name");
    }

    unless ( $query = $library->query('set_feeder_table') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'set_feeder_table' cannot be retrieved from the library");
    }

    my $feedername = $feeder->name;
 
    unless ( $oracle->do( statement => $query, values => [ $name, $id ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot rename feedertable to $name for feeder $feedername");
    }

    $logger->debug("feedertable renamed to $name for feeder $feedername");

    return 1;
}

#--------------#
sub set_job_id {
#--------------#
    my ( $self, $job_id ) = @_;


    $self->{job_id} = $job_id;
}

#----------------#
sub set_ref_data {
#----------------#
    my ( $self, $ref_data ) = @_;


    $self->{ref_data} = $ref_data;
}

#--------------------#
sub count_nr_records {
#--------------------#
    my ( $self ) = @_;

    
    my $logger   = $self->{logger};
    my $config   = $self->{config};
    my $library  = $self->{library};
    my $oracle   = $self->{oracle_rep};
    my $name     = $self->{name};
    my $job_id   = $self->{job_id}; 
    my $ref_data = $self->{ref_data}; 

    unless ( $job_id && $ref_data ) {
        $logger->error("cannot count the number of records in a feedertable without a job id and a data ref");
        return;
    }

    my $query;
    unless ( $query = $library->query('nr_rows') ) {
        $logger->logdie("query with as key 'nr_rows' cannot be retrieved from the library");
    }

    $name =~ s/\.REP$/_REP/;

    $query =~ s/__TABLE__/$name/;

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $ref_data, $job_id ] ) ) {
        $logger->error("unable to count the number of records in feedertable $name");
        return;
    }

    my $nr_records = $self->{nr_records} = $result->nextref->[0];

    $logger->debug("feedertable $name contains $nr_records records for job id $job_id and data ref $ref_data");

    return $nr_records;
}

#---------#
sub store {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in store of feedertable (db_audit)");
    }

    my $session_id;
    unless ( $session_id = $args{session_id} ) {
        $logger->logdie("missing argument in store of feedertable (session_id)");
    }

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument in store of feedertable (entity)");
    }

    my $runtype;
    unless ( $runtype = $args{runtype} ) {
        $logger->logdie("missing argument in store of feedertable (runtype)");
    }

    $db_audit->record_feedertable( session_id => $session_id, name => $self->{name}, batch_name => $self->{feeder}->batchname, feeder_name => $self->{feeder}->name, entity => $entity, runtype => $runtype, job_id => $self->{job_id}, ref_data => $self->{ref_data}, nr_records => $self->{nr_records}, tabletype => $self->{type} );
}

#------------#
sub retrieve {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

	my $self = {};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in retrieve of feedertable (db_audit)");
    }

    my $id;
    unless ( $id = $args{id} ) {
        $logger->logdie("missing argument in retrieve of feedertable (id)");
    }

	if ( my $row = $db_audit->retrieve_feedertable( id => $id ) ) {
	    $self->{id}          = $id;
	    $self->{session_id}  = $row->[1];
	    $self->{name}        = $row->[2];
	    $self->{batch_name}  = $row->[3];
	    $self->{feeder_name} = $row->[4];
	    $self->{entity}      = $row->[5];
	    $self->{runtype}     = $row->[6];
	    $self->{timestamp}   = $row->[7];
	    $self->{job_id}      = $row->[8];
	    $self->{ref_data}    = $row->[9];
	    $self->{nr_records}  = $row->[10];
	    $self->{tabletype}   = $row->[11];

	    bless $self, $class;

	    return $self;
    }
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#------------#
sub ref_data {
#------------#
    my ( $self ) = @_;

    return $self->{ref_data};
}

#----------#
sub feeder {
#----------#
    my ( $self ) = @_;

    return $self->{feeder};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;

    return $self->{type};
}

1;

