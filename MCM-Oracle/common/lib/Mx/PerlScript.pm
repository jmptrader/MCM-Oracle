package Mx::PerlScript;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::DBaudit;
use Mx::Process;
use Mx::Alert;
use File::Basename;
use File::Spec;
use Carp;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $self = {};
    $self->{logger} = $logger;

    my $logfile = $logger->filename;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Perl Script (config)");
    }
    $self->{config} = $config;

    my $process = $self->{process} = Mx::Process->new( config => $config, logger => $logger );

    my $scriptname = basename( $0 );
    my $path       = File::Spec->rel2abs( $0 );

    $self->{scriptname} = $scriptname;
    $self->{project}    = $process->project;
    $self->{sched_js}   = $process->sched_js;

    my $db_audit = $self->{db_audit} = Mx::DBaudit->new( config => $config, logger => $logger );

    my $id = $self->{id} = $db_audit->record_script_start(
      scriptname      => $scriptname,
      path            => $path,
      cmdline         => $process->cmdline,
      hostname        => $process->hostname,
      pid             => $process->pid,
      username        => $process->username,
      starttime       => $process->starttime,
      project         => $process->project,
      sched_jobstream => $process->sched_js,
      name            => $process->name,
      logfile         => $logfile,
    );

    bless $self, $class;
}

#----------#
sub finish {
#----------#
    my ( $self, %args ) = @_;


    my $id       = $self->{id};
    my $process  = $self->{process};
    my $exitcode = $args{exitcode} || 0;

    my ( $cpu_seconds, $vsize ) = Mx::Process->cpu_seconds_and_vsize( $process->pid );

    my $db_audit = $self->{db_audit};

    $db_audit->record_script_end(
      id          => $id,
      exitcode    => $exitcode,
      cpu_seconds => $cpu_seconds,
      vsize       => $vsize
    );

    $db_audit->close;

    return 0;
}

#--------#
sub fail {
#--------#
    my ( $self, %args ) = @_;


    my $send_alert = ( exists $args{alert} ) ? $args{alert} : 1;

    $self->finish( exitcode => 1 );

    if ( $send_alert ) {
        my $alert = Mx::Alert->new( name => 'script_failure', config => $self->{config}, logger => $self->{logger} );

        $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $self->{scriptname}, $self->{project} ], item => $self->{scriptname} );
    }

    return 1;
}

#----------------#
sub fail_and_die {
#----------------#
    my( $self, $message ) = @_;


    $self->fail;

    $self->{logger}->logdie( $message );
}

#------#
sub id {
#------#
    my ( $self ) = @_;


    return $self->{id};
}

#------------#
sub db_audit {
#------------#
    my ( $self ) = @_;


    return $self->{db_audit};
}

1;
