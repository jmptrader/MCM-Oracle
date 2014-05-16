package Mx::Datamart::Feeder;

use strict;
use warnings;

use Mx::Datamart::Feedertable;
use Carp;

#
# Properties:
#
# $id
# $name
# $batchname
# $job_id
# $ref_data
# @tables
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $id         = $self->{id}         = $args{id};
    my $name       = $self->{name}       = $args{name};
    my $batchname  = $self->{batchname}  = $args{batchname};
    my $logger     = $self->{logger}     = $args{logger};
    my $config     = $self->{config}     = $args{config};
    my $oracle     = $self->{oracle}     = $args{oracle};
    my $oracle_rep = $self->{oracle_rep} = $args{oracle_rep};
    my $library    = $self->{library}    = $args{library};
    my $semaphore  = $self->{semaphore}  = $args{semaphore};

    bless $self, $class;

    $logger->info("feeder $name identified (id: $id)");

    my @tables = Mx::Datamart::Feedertable->retrieve_all( feeder => $self, library => $library, oracle => $oracle, oracle_rep => $oracle_rep, semaphore => $semaphore, config => $config, logger => $logger );
    
    $self->{tables} = [ @tables ];

    my $nr_dynamic_tables = 0;
    foreach my $table ( @tables ) {
        $nr_dynamic_tables++ if $table->type eq $Mx::Datamart::Feedertable::TYPE_DYNAMIC;
    }

    $self->{nr_dynamic_tables} = $nr_dynamic_tables;

    $logger->info("number of dynamic tables in this feeder: $nr_dynamic_tables");

    return $self;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @feeders;

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of feeder (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of feeder (oracle)");
    }

    my $oracle_rep;
    unless ( $oracle_rep = $args{oracle_rep} ) {
        $logger->logdie("missing argument in initialisation of feeder (oracle_rep)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in initialisation of feeder (library)");
    }

    my $batchname;
    unless ( $batchname = $args{batchname} ) {
        $logger->logdie("missing argument in initialisation of feeder (batchname)");
    }

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in initialisation of feeder (semaphore)");
    }

    my $query;
    unless ( $query = $library->query('get_feeders') ) {
        $logger->logdie("query with as key 'get_feeders' cannot be retrieved from the library");
    }

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $batchname ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve feeders for batch $batchname");
    }

	while ( my ( $id, $name ) = $result->next ) {
        push @feeders, Mx::Datamart::Feeder->new( id => $id, name => $name, batchname => $batchname, library => $library, oracle => $oracle, oracle_rep => $oracle_rep, semaphore => $semaphore, config => $config, logger => $logger );
    }

    return @feeders;
}

#-----------------#
sub update_tables {
#-----------------#
    my ( $self , %args ) = @_;


    my $logger    = $self->{logger};
    my @tables    = @{$self->{tables}};

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument in update_tables (entity)");
    }

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in update_tables (semaphore)");
    }

    foreach my $table ( @tables ) {
        $table->update_name( entity => $entity, semaphore => $semaphore );
    }
}

#--------------#
sub set_job_id {
#--------------#
    my ( $self, $job_id ) = @_;


    my @tables = @{$self->{tables}};

    $self->{job_id} = $job_id;

    foreach my $table ( @tables ) {
        $table->set_job_id( $job_id );
    }
}

#----------------#
sub set_ref_data {
#----------------#
    my ( $self, $ref_data ) = @_;


    my @tables = @{$self->{tables}};

    $self->{ref_data} = $ref_data;

    foreach my $table ( @tables ) {
        $table->set_ref_data( $ref_data );
    }
}

#--------------------#
sub count_nr_records {
#--------------------#
    my ( $self ) = @_;


    my @tables = @{$self->{tables}};

    my $nr_dynamic_records = 0;
    foreach my $table ( @tables ) {
        my $nr_records = $table->count_nr_records || 0;

        $nr_dynamic_records += $nr_records if $table->type eq $Mx::Datamart::Feedertable::TYPE_DYNAMIC;
    }

    return $nr_dynamic_records;
}

#---------#
sub store {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my @tables = @{$self->{tables}};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in store of feeder (db_audit)");
    }

    my $session_id;
    unless ( $session_id = $args{session_id} ) {
        $logger->logdie("missing argument in store of feeder (session_id)");
    }

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument in store of feeder (entity)");
    }

    my $runtype;
    unless ( $runtype = $args{runtype} ) {
        $logger->logdie("missing argument in store of feeder (runtype)");
    }

    foreach my $table ( @tables ) {
        $table->store( %args );
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

#-------------#
sub batchname {
#-------------#
    my ( $self ) = @_;

    return $self->{batchname};
}

#----------#
sub tables {
#----------#
    my ( $self ) = @_;

    return @{$self->{tables}};
}

#---------------------#
sub nr_dynamic_tables {
#---------------------#
    my ( $self ) = @_;

    return $self->{nr_dynamic_tables};
}

1;

