package Mx::Remote;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Alert;
use Carp;

my $STATUS_INITIALIZED    = 'initialized';
my $STATUS_WAITING_SYBASE = 'waiting sybase';
my $STATUS_WAITING_SEMA   = 'waiting sema';
my $STATUS_RUNNING        = 'running';
my $STATUS_FINISHED       = 'finished';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $self = {};
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of remote object (config)");
    }
    $self->{config} = $config;

    my $db_audit = $self->{db_audit} = Mx::DBaudit->new( config => $config, logger => $logger );

    $self->{instance}   = $args{instance};
    $self->{command}    = $args{command};
    $self->{nowait}     = ( $args{nowait} ) ? 'Y' : 'N';
    $self->{timeout}    = $args{timeout} || 0;
    $self->{force_ok}   = ( $args{force_ok} ) ? 'Y' : 'N';
    $self->{sched_js}   = $args{sched_js};
    $self->{project}    = $args{project};
    $self->{semaphores} = $args{semaphores};

    $self->{status}    = $STATUS_INITIALIZED;
    $self->{starttime} = time();

    my @semaphores = @{$self->{semaphores}};

    my $id = $self->{id} = $db_audit->record_remote_start(
      instance        => $self->{instance},
      command         => $self->{command},
      nowait          => $self->{nowait},
      timeout         => $self->{timeout},
      force_ok        => $self->{sched_js},
      project         => $self->{project},
      status          => $self->{status},
      starttime       => $self->{starttime},
      semaphore0      => $semaphores[0],
      semaphore1      => $semaphores[1],
      semaphore2      => $semaphores[2],
      semaphore3      => $semaphores[3],
      semaphore4      => $semaphores[4]
    );

    bless $self, $class;
}

#-------------------#
sub wait_for_sybase {
#-------------------#
    my ( $self ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};

    $self->{sybase_timestamp} = time();
    $self->{status}           = $STATUS_WAITING_SYBASE;

    $db_audit->update_remote(
      id     => $id,
      status => $self->{status}
    );
}

#---------------------#
sub waited_for_sybase {
#---------------------#
    my ( $self ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};

    $db_audit->update_remote(
      id           => $id,
      sybase_delay => time() - $self->{sybase_timestamp}
    );
}

#--------------------------#
sub waiting_for_semaphores {
#--------------------------#
    my ( $self ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};

    $self->{semaphore_timestamp} = time();
    $self->{status}              = $STATUS_WAITING_SEMA;

    $db_audit->update_remote(
      id     => $id,
      status => $self->{status}
    );
}

#-------------------------#
sub waited_for_semaphores {
#-------------------------#
    my ( $self ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};

    $db_audit->update_remote(
      id           => $id,
      sybase_delay => time() - $self->{semaphore_timestamp}
    );
}

#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};

    $self->{total_delay}     = time() - $self->{starttime};
    $self->{actual_instance} = $args{instance};
    $self->{status}          = $STATUS_RUNNING;

    $db_audit->update_remote(
      id              => $id,
      total_delay     => $self->{total_delay},
      actual_instance => $self->{actual_instance},
      status          => $self->{status}
    );
}

#----------#
sub finish {
#----------#
    my ( $self, %args ) = @_;


    my $id       = $self->{id};
    my $db_audit = $self->{db_audit};
    my $exitcode = $args{exitcode} || 0;

    $db_audit->record_remote_end(
      id          => $id,
      exitcode    => $exitcode,
      endtime     => time()
    );

    return 0;
}

#--------#
sub fail {
#--------#
    my ( $self ) = @_;


    $self->finish( exitcode => 1 );

    my $alert = Mx::Alert->new( name => 'remote_failure', config => $self->{config}, logger => $self->{logger} );

    $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $self->{id}, $self->{project} ], item => $self->{id} );

    return 1;
}

#------#
sub id {
#------#
    my ( $self ) = @_;


    return $self->{id};
}

1;
