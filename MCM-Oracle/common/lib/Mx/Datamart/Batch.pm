package Mx::Datamart::Batch;

use strict;
use DBI;
use Data::Dumper;
use Mx::GenericScript;
use Mx::Datamart::Filter;
use Mx::Scheduler;
use Mx::Murex;
use Mx::DBaudit;
use Carp;

our @ISA = qw(Mx::GenericScript);

*errstr = *Mx::GenericScript::errstr;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    unless ( $args{oracle} ) {
        $args{logger}->logdie("missing argument (oracle)");
    }

    unless ( $args{library} ) {
        $args{logger}->logdie("missing argument (library)");
    }

    my $self = $class->SUPER::new(%args, type => Mx::GenericScript::DM_BATCH);

    $self->{noconfig} = $args{noconfig};
    $self->{norun}    = $args{norun};

    $self->_read_config();

    $self->_set_nr_engines();

    return $self;
}

#----------------#
sub _read_config {
#----------------#
    my ( $self ) = @_;


    my $logger  = $self->{logger};
    my $config  = $self->{config};
    my $oracle  = $self->{oracle};
    my $library = $self->{library};
    my $entity  = $self->{entity};
    my $runtype = $self->{runtype};
    my $name    = $self->{name};

    my $batch_configfile     = $config->retrieve('DM_BATCH_CONFIGFILE');
    my $batch_config         = Mx::Config->new( $batch_configfile );
    $self->{batchconfig}     = $batch_config;

    my $batch_ref = $batch_config->retrieve( "%DM_BATCHES%$name", 1 ) || $batch_config->retrieve( '%DM_BATCHES%DEFAULT' );
    my $batchname = $batch_ref->{name};
    my $label     = $batch_ref->{label};
    my $exc_tmpl  = $batch_ref->{exc_tmpl};

    $batchname =~ s/__NAME__/$name/;

    $self->{batch_size} = ( exists $batch_ref->{batch_size} ) ? $batch_ref->{batch_size} : $config->DM_BATCH_SIZE;
    $self->{nr_retries} = ( exists $batch_ref->{nr_retries} ) ? $batch_ref->{nr_retries} : $config->DM_NR_RETRIES;
    $self->{nr_engines} = ( exists $batch_ref->{nr_engines} ) ? $batch_ref->{nr_engines} : undef;
    if ( exists $batch_ref->{scanner_nickname} ) {
      $self->{extra_args} .= ' /SCANNER_NICKNAME:' . $batch_ref->{scanner_nickname};
    }
    $self->{batchname} = $batchname;
    $self->{label}     = $label;
    $self->{exc_tmpl}  = $exc_tmpl;
    $self->{filter}    = Mx::Datamart::Filter->new( batch_label => $name, entity => $entity, runtype => $runtype, oracle => $oracle, library => $library, config => $config, logger => $logger ) unless $self->{noconfig};
}

#-------------------#
sub _set_nr_engines {
#-------------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $config     = $self->{config};
    my $batchname  = $self->{batchname};
    my $entity     = $self->{entity};
    my $runtype    = $self->{runtype};

    if ( defined $self->{nr_engines} ) {
        $logger->info('number of engines set to ' . $self->{nr_engines} . ' (config file)');
        return;
    }

    my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

    my ( $nr_samples, $avg_nr_engines, $avg_nr_records ) = $db_audit->retrieve_average_scanner_info( mx_scriptname => $batchname, entity => $entity, runtype => $runtype );

    $db_audit->close();

    if ( ! defined $nr_samples or $nr_samples == 0 ) {
        $self->{nr_engines} = $config->DM_NR_ENGINES;
        $logger->info('number of engines set to ' . $self->{nr_engines} . ' (default)');
        return;
    }

    $logger->info("average number of records: $avg_nr_records");

    my $nr_engines = int( $avg_nr_records / 100000 );

    if ( $nr_engines == 0 ) {
        $nr_engines = 1;
    }
    elsif ( $nr_engines > 8 ) {
        $nr_engines = 8;
    }

    $self->{nr_engines} = $nr_engines;

    $logger->info('number of engines set to ' . $self->{nr_engines} . ' (computed)');
}

#-------------#
sub set_label {
#-------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $entity     = $self->{entity};
    my $runtype    = $self->{runtype};
    my $batchname  = $self->{batchname};
    my $label      = $self->{label} || '__RUNTYPE____ENTITY__';

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in set_label (semaphore)");
    }

    my $short_entity = Mx::Scheduler->entity_long2short( $entity );

    $label =~ s/__ENTITY__/$short_entity/g;
    $label =~ s/__RUNTYPE__/$runtype/g;

    my $query;
    unless ( $query = $library->query('set_batch_label') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'set_batch_label' cannot be retrieved from the library");
    }

    unless ( $oracle->do( statement => $query, values => [ $label, $batchname ] ) == 1 ) {
        $semaphore->release();
        $logger->logdie("cannot set label of batch to '$label'");
    }

    $logger->debug("label of batch set to '$label'");

    return 1;
}

#------------------#
sub set_cmd_before {
#------------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $batchname  = $self->{batchname};

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in set_cmd_before (semaphore)");
    }

    my $query;
    unless ( $query = $library->query('set_cmd_before') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'set_cmd_before' cannot be retrieved from the library");
    }

    unless ( $oracle->do( statement => $query, values => [ 'dm_before.pl', $batchname ] ) == 1 ) {
        $semaphore->release();
        $logger->logdie("cannot initialize before command of batch");
    }

    $logger->debug("before command of batch initialized");

    return 1;
}

#---------------#
sub set_scanner {
#---------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $session_id = $self->{id};
    my $batchname  = $self->{batchname};
    my $nr_engines = $self->{nr_engines};

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in set_scanner (semaphore)");
    }

    my $batch_size; my $nr_retries;
    if ( $nr_engines != 0 ) {
        unless ( $batch_size = $args{batch_size} ) {
            $semaphore->release();
            $logger->logdie("missing argument in set_scanner (batch_size)");
        }

        unless ( exists $args{nr_retries} ) {
            $semaphore->release();
            $logger->logdie("missing argument in set_scanner (nr_retries)");
        }
        $nr_retries = $args{nr_retries};
    }

    my $scanner_id = 0;
    if ( $nr_engines != 0 ) {
        my $query;
        unless ( $query = $library->query('get_unique_scanner_id') ) {
            $semaphore->release();
            $logger->logdie("query with as key 'get_unique_scanner_id' cannot be retrieved from the library");
        }

		$oracle->do( statement => $query, io_values => [ \$scanner_id ] );

        unless ( $scanner_id ) {
            $logger->error("SQL query failed, cannot retrieve unique scanner id");
            return;
        }

        my $scanner_name = 'BATCH_' . $session_id;

        unless ( $query = $library->query('insert_scanner') ) {
            $semaphore->release();
            $logger->logdie("query with as key 'insert_scanner' cannot be retrieved from the library");
        }

        unless ( $oracle->do( statement => $query, values => [ $scanner_id, $scanner_name, $nr_engines, $batch_size, $nr_retries, $batch_size ] ) == 1 ) {
            $semaphore->release();
            $logger->logdie("cannot insert new scanner");
        }
    }

    my $query;
    unless ( $query = $library->query('set_scanner') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'set_scanner' cannot be retrieved from the library");
    }

    unless ( $oracle->do( statement => $query, values => [ $scanner_id, $batchname ] ) == 1 ) {
        $semaphore->release();
        $logger->logdie("cannot set new scanner");
    }

    $self->{scanner_id} = $scanner_id;

    if ( $nr_engines == 0 ) {
        $logger->info("batch scanner disabled");
    }
    else {
        $logger->info("batch scanner initialized (nr of engines: $nr_engines - batch size: $batch_size - nr of retries: $nr_retries)");
    }

    return 1;
}

#--------------------------#
sub set_exception_template {
#--------------------------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $batchname  = $self->{batchname};

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in set_exception_template (semaphore)");
    }

    unless ( exists $args{name} ) {
        $semaphore->release();
        $logger->logdie("missing argument in set_exception_template (name)");
    }
    my $templatename = $args{name};

    my $template_id = 0;

    if ( $templatename ) {
        my $query;
        unless ( $query = $library->query('get_exc_tmpl') ) {
            $semaphore->release();
            $logger->logdie("query with as key 'get_exc_tmpl' cannot be retrieved from the library");
        }

        my $result;
        unless ( $result = $oracle->query( query => $query, values => [ $templatename ] ) ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve exception template with label $templatename");
        }

        $template_id = $result->nextref->[0];
    }

    my $query;
    unless ( $query = $library->query('set_exc_tmpl') ) {
        $semaphore->release();
        $logger->logdie("query with as key 'set_exc_tmpl' cannot be retrieved from the library");
    }

    unless ( $oracle->do( statement => $query, values => [ $template_id, $batchname ] ) == 1 ) {
        $semaphore->release();
        $logger->logdie("cannot set new exception template ($templatename)");
    }

    $self->{exc_tmpl_id} = $template_id;

    if ( $templatename ) {
        $logger->info("exception template set ($templatename)");
    }
    else {
        $logger->info("exception template disabled");
    }

    return 1;
}

#--------------------#
sub cleanup_scanners {
#--------------------#
    my ( $self ) = @_;


    my $logger  = $self->{logger};
    my $oracle  = $self->{oracle};
    my $library = $self->{library};

    my $query;
    unless ( $query = $library->query('cleanup_scanners') ) {
        $logger->logdie("query with as key 'cleanup_scanners' cannot be retrieved from the library");
    }

    my $nr_rows = $oracle->do( statement => $query );

    $logger->info("$nr_rows scanner templates cleaned up");
}

#-------------------#
sub cleanup_scanner {
#-------------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $scanner_id = $self->{scanner_id};

    return unless $scanner_id;

    my $query;
    unless ( $query = $library->query('cleanup_scanner') ) {
        $logger->logdie("query with as key 'cleanup_scanner' cannot be retrieved from the library");
    }

    if ( $oracle->do( statement => $query, values => [ $scanner_id ] ) ) {
        $logger->info("scanner template cleaned up ($scanner_id)");
    }
    else {
        $logger->warn("unable to cleanup scanner template ($scanner_id)");
    }
}

#------------#
sub job_info {
#------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $oracle     = $self->{oracle};
    my $library    = $self->{library};
    my $db_audit   = $self->{db_audit};
    my $session_id = $self->{id};
    my $batchname  = $self->{batchname};
    my $start_date = $self->{start_date};

    my $pid;
    unless ( $pid = $db_audit->get_pid( session_id => $session_id ) ) {
        $logger->error("cannot retrieve pid for session $session_id");
        return;
    }

    my $query;
    unless ( $query = $library->query('job_info') ) {
        $logger->logdie("query with as key 'job_info' cannot be retrieved from the library");
    }

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $start_date, $batchname, $pid ] ) ) {
        $logger->error("cannot retrieve job info for batch $batchname with pid $pid on $start_date");
        return;
    }

    my ( $job_id, $status, $ref_data ) = $result->next;

    $logger->info("retrieved job info for batch $batchname with pid $pid on $start_date");
    $logger->info("status: $status - job id: $job_id - ref data: $ref_data");

    return( $job_id, $ref_data );
}

#----------------#
sub scanner_info {
#----------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $oracle    = $self->{oracle_rep};
    my $library   = $self->{library};
    my $job_id    = $args{job_id};
    my $batchname = $self->{batchname};

    my $query;
    unless ( $query = $library->query('scanner_info') ) {
        $logger->logdie("query with as key 'scanner_info' cannot be retrieved from the library");
    }

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $job_id ] ) ) {
        $logger->error("cannot retrieve scanner info for batch $batchname with job id $job_id");
        return;
    }

    my ( $scanner_id, $nr_batches, $nr_items ) = $result->next;

    $logger->info("number of batches: $nr_batches - number of items: $nr_items");

    unless ( $query = $library->query('item_info') ) {
        $logger->logdie("query with as key 'item_info' cannot be retrieved from the library");
    }

    $result = $oracle->query( query => $query, values => [ $scanner_id ] );

	my $nr_missing_items; 
    unless ( $nr_missing_items = $result->size ) {
        $logger->info("no missing items found for batch $batchname with scanner id $scanner_id");

        return( $nr_batches, $nr_items, 0 );
    }

    if ( $nr_missing_items ) {
        $logger->warn("found $nr_missing_items missing items");
    }
    else {
        $logger->info("no missing items");
    }

    return( $nr_batches, $nr_items, $nr_missing_items, [ $result->all_rows ] );
}

1;
