package Mx::ResourcePool;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Secondary;
use Mx::Alert;
use Carp;

my $STATUS_INITIALIZED  = 'initialized';
my $STATUS_ACQUIRED     = 'acquired';
my $STATUS_RELEASED     = 'released';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $self = {};
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of resourcepool (config)");
    }
    $self->{config} = $config;

    unless ( $self->{db_audit} = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of resourcepool (db_audit)");
    }

    my $hostname = $self->{hostname} = $args{hostname};

    $hostname ||= Mx::Util->hostname();

    $self->{cpu_resourcename}       = 'cpu_' . $hostname;
    $self->{io_resourcename}        = 'io_' .  $hostname;
    $self->{global_io_resourcename} = $config->DSQUERY;

    $self->{cpu_value} = 0;
    $self->{io_value}  = 0;

    $self->{status}    = $STATUS_INITIALIZED;
    $self->{timestamp} = undef;

    bless $self, $class;
}

#-----------#
sub acquire {
#-----------#
    my ( $self, %args ) = @_;



    my $logger   = $self->{logger};
    my $status   = $self->{status};
    my $db_audit = $self->{db_audit};

    unless ( $status eq $STATUS_INITIALIZED or $status eq $STATUS_RELEASED ) {
        $logger->error("cannot acquire a resourcepool with as status '$status'");
        return;
    }

    $self->{timestamp} = time();

    my $mx_scripttype = $args{mx_scripttype};
    my $mx_scriptname = $args{mx_scriptname};
    my $mx_scanner    = $args{mx_scanner};
    my $entity        = $args{entity};
    my $runtype       = $args{runtype};

    if ( $mx_scripttype eq 'user session' ) {
        $self->{cpu_value} = 0.20;
        $self->{io_value}  = 0.0075;
    }
    elsif ( ( $mx_scripttype eq 'batch' ) or ( $mx_scripttype eq 'dm_batch' && ! $mx_scanner ) ) {
        my ( $count, $avg_runtime, $avg_cputime, $avg_iotime, $avg_cpu_seconds ) = $db_audit->retrieve_average_batch_info( mx_scriptname => $mx_scriptname, mx_scripttype => $mx_scripttype, entity => $entity, runtype => $runtype );

        if ( $avg_runtime ) {
            $self->{cpu_value} = sprintf "%.2f", $avg_cputime / $avg_runtime;
            $self->{io_value}  = sprintf "%.2f", $avg_iotime  / $avg_runtime;
        }
    }
    elsif ( $mx_scripttype eq 'scanner' ) {
        my ( $count, $avg_nr_engines, $avg_nr_table_records, $avg_total_runtime, $avg_total_cputime, $avg_total_iotime, $avg_total_cpu_seconds ) = $db_audit->retrieve_average_scanner_info( mx_scriptname => $mx_scriptname, entity => $entity, runtype => $runtype );

        if ( $avg_total_runtime ) {
            $self->{cpu_value} = sprintf "%.2f", $avg_total_cputime / $avg_total_runtime;
            $self->{io_value}  = sprintf "%.2f", $avg_total_iotime  / $avg_total_runtime;
        }
    }

    if ( $self->{cpu_value} != 0 ) {
        $db_audit->update_resource( name => $self->{cpu_resourcename}, increment => -1 * $self->{cpu_value} );
        $logger->debug('# CPU resources claimed: ' . $self->{cpu_value});
    }

    if ( $self->{io_value} != 0 ) {
        $db_audit->update_resource( name => $self->{global_io_resourcename}, increment => -1 * $self->{io_value} );
        $db_audit->update_resource( name => $self->{io_resourcename}, increment => -1 * $self->{io_value} );
        $logger->debug('# IO resources claimed: ' . $self->{io_value});
    }

    $self->{status} = $STATUS_ACQUIRED;

    return 1;
}

#-----------#
sub release {
#-----------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $status   = $self->{status};
    my $db_audit = $self->{db_audit};

    unless ( $status eq $STATUS_ACQUIRED ) {
        $logger->error("cannot release a resourcepool with as status '$status'");
        return;
    }

    if ( $self->{cpu_value} != 0 ) {
        $db_audit->update_resource( name => $self->{cpu_resourcename}, increment => $self->{cpu_value} );
        $logger->debug('# CPU resources released: ' . $self->{cpu_value});
    }

    if ( $self->{io_value} != 0 ) {
        $db_audit->update_resource( name => $self->{global_io_resourcename}, increment => $self->{io_value} );
        $db_audit->update_resource( name => $self->{io_resourcename},        increment => $self->{io_value} );
        $logger->debug('# IO resources released: ' . $self->{io_value});
    }

    $self->{status} = $STATUS_RELEASED;

    return 1;
}

#---------#
sub reset {
#---------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    
    my ( $cpu_result ) = $db_audit->retrieve_resources( name => $self->{cpu_resourcename} );

    $db_audit->update_resource( name => $self->{cpu_resourcename}, value => $cpu_result->{initial_size} );
    $logger->info('resource ' .  $self->{cpu_resourcename} . ' reset to initial size ' . $cpu_result->{initial_size});

    my ( $io_result ) = $db_audit->retrieve_resources( name => $self->{io_resourcename} );

    my $io_acquired = sprintf "%.2f", $io_result->{initial_size} - $io_result->{value};

    $db_audit->update_resource( name => $self->{io_resourcename}, value => $io_result->{initial_size} );
    $logger->info('resource ' . $self->{io_resourcename} . ' reset to initial size ' . $io_result->{initial_size});

    $db_audit->update_resource( name => $self->{global_io_resourcename}, increment => $io_acquired );
    $logger->info('resource ' .  $self->{global_io_resourcename} . ' incremented with ' . $io_acquired);
}

#---------------#
sub globalreset {
#---------------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $config   = $self->{config};
    my $db_audit = $self->{db_audit};

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );

    shift @app_servers; # skip Linux

    foreach my $app_server ( @app_servers ) {
        foreach my $type ( 'cpu', 'io' ) {
            my $name = $type . '_' . Mx::Util->hostname( $app_server );

            my ( $result ) = $db_audit->retrieve_resources( name => $name );

            $db_audit->update_resource( name => $name, value => $result->{initial_size} );

            $logger->info("resource $name reset to initial size " . $result->{initial_size});
        }
    }

    my $name = $self->{global_io_resourcename};

    my ( $result ) = $db_audit->retrieve_resources( name => $name );

    $db_audit->update_resource( name => $name, value => $result->{initial_size} );

    $logger->info("resource $name reset to initial size " . $result->{initial_size});
}

#---------#
sub setup {
#---------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $config   = $self->{config};
    my $db_audit = $self->{db_audit};

    my @resources = ();

    my $sa_account = Mx::Account->new( name => $config->MX_TSUSER, config => $config, logger => $logger );

    my $sa_sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $sa_account->name, password => $sa_account->password, config => $config, logger => $logger, error_handler => 1, nocache => 1 );

    $sa_sybase->open();

    my $nr_engines = $sa_sybase->nr_engines();

    $sa_sybase->close();

    push @resources, { name => $config->DSQUERY, value => $nr_engines * $config->IO_RESOURCES_CORRECTION_FACTOR };

    my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

    shift @handles; # skip Linux server

    map { $_->system_info_async } @handles;

    my @servers = ();
    foreach my $handle ( @handles ) {
        push @servers, $handle->poll_async;
    }

    foreach my $server ( @servers ) {
        my $hostname = Mx::Util->hostname( $server->{hostname} );

        my $nr_cores = $server->{nr_cores};

        push @resources, { name => 'cpu_' . $hostname, value => $nr_cores   * $config->CPU_RESOURCES_CORRECTION_FACTOR };
        push @resources, { name => 'io_' .  $hostname, value => $nr_engines * $config->IO_RESOURCES_CORRECTION_FACTOR / scalar( @servers ) };
    }

    foreach my $resource ( @resources ) {
        my $name  = $resource->{name};
        my $value = $resource->{value};

        $db_audit->record_resource( name => $name, value => $value );

        $logger->info("resource $name set to initial value $value");
    }
}

#-------------#
sub resources {
#-------------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};

    my @resources = $db_audit->retrieve_resources();

    return @resources;
}

1;
