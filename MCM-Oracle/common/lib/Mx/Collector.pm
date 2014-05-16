package Mx::Collector;

use strict;
use warnings;

use Carp;
use Mx::Process;

my $STATUS_UNKNOWN    = 'unknown';
my $STATUS_RUNNING    = 'running'; 
my $STATUS_STOPPED    = 'stopped';
my $STATUS_DISABLED   = 'disabled';

my $SOFT_DISABLED     = 1;
my $HARD_DISABLED     = 2;

my @DISABLED_COLLECTORS = ();

my $START_DELAY = 5;

#
# properties:
#
# name 
# descriptor
# description
# order
# logfile
# flagfile
# pidfile
# rrdfile
# hires_rrdfile
# rrdfile2
# path
# poll_interval
# process
# status
# location
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $self = {};

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex collector (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex collector (config)");
    }

    my $collector_ref;
    unless ( $collector_ref = $config->retrieve("%COLLECTORS%$name") ) {
        $logger->logdie("collector '$name' is not defined in the configuration file");
    }

    $logger->debug("initializing collector $name");

    foreach my $param (qw(descriptor description order logfile flagfile pidfile rrdfile hires_rrdfile rrdfile2 path poll_interval location)) {
        unless ( exists $collector_ref->{$param} ) {
            $logger->logdie("parameter '$param' for collector '$name' is not defined in the configuration file");
        }
        $self->{$param} = $collector_ref->{$param};
    }

    #
    # check if the location is properly defined
    #
    unless ( $self->{location} =~ /^\d+$/ ) {
        $logger->logdie('wrong location specified: ', $self->{location});
    }

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
    my $app_srv_short = Mx::Util->hostname( $app_servers[ $self->{location} ] );

    $self->{logfile}       =~ s/__APP_SRV_SHORT__/$app_srv_short/;
    $self->{flagfile}      =~ s/__APP_SRV_SHORT__/$app_srv_short/;
    $self->{pidfile}       =~ s/__APP_SRV_SHORT__/$app_srv_short/;
    $self->{rrdfile}       =~ s/__APP_SRV_SHORT__/$app_srv_short/;
    $self->{hires_rrdfile} =~ s/__APP_SRV_SHORT__/$app_srv_short/;
    $self->{rrdfile2}      =~ s/__APP_SRV_SHORT__/$app_srv_short/;
 
    $self->{logger} = Mx::Log->new( filename => $self->{logfile} );

    $logger->debug("collector $name initialized");

    if ( grep /^$name$/, @DISABLED_COLLECTORS ) {
        $self->{status} = $STATUS_DISABLED;
    }
    else {
        $self->{status} = $STATUS_UNKNOWN;
    }
    
    bless $self, $class; 
}

#---------#
sub start {
#---------#
    my ( $self, %args ) = @_;


    my $logger  = $self->{logger};
    my $config  = $self->{config};
    my $path    = $self->{path};
    my $logfile = $self->{logfile};

    $logger->info("starting collector");

    my $disabled = $self->is_disabled();
    if ( ( ! $args{enable} and $disabled == $SOFT_DISABLED ) or ( $disabled == $HARD_DISABLED ) ) {
        $logger->error("collector is disabled, not allowed to start");
        return
    }

    $self->check();

    unless ( $self->{status} eq $STATUS_STOPPED ) {
        $logger->error("can only start a stopped collector");
        return;
    }

    my $command = "$path $logfile";

    if ( $args{apache_request} ) {
        Mx::Process->run( command => $command, logger => $logger, config => $config, directory => $config->BINDIR, apache_request => $args{apache_request}, logfile => $logfile );
    }
    else {
        unless ( Mx::Process->background_run( command => $command, logger => $logger, config => $config, directory => $config->BINDIR, ignore_child => 1 ) ) {
            $logger->error("collector cannot be started");
            return;
        }
    }

    sleep( $START_DELAY );

    $self->check();

    $self->_enable() if $args{enable};

    unless ( $self->{status} eq $STATUS_RUNNING ) {
        $logger->error("collector process not found");
        return;
    }

    $logger->info("collector started");

    return 1;
}

#--------#
sub stop {
#--------#
    my ( $self, %args ) = @_;


    if ( $self->{status} eq $STATUS_DISABLED ) {
        return;
    }

    $self->_disable() if $args{disable};

    my $logger  = $self->{logger};

    $logger->info("stopping collector");

    $self->check();

    unless ( $self->{status} eq $STATUS_RUNNING ) {
        $logger->error("can only stop a running collector");
        return;
    }

    my $process = $self->{process};
    unless ( $process and ref($process) eq 'Mx::Process' ) {
        $logger->error("no process found");
        return;
    }

    unless ( $process->kill( recursive => 1 ) ) {
        $logger->error("collector cannot be stopped");
        return;
    }

    $process->remove_pidfile();

    $self->{process} = undef;
    $self->{status}  = $STATUS_STOPPED;

    $logger->info("collector stopped");

    return 1;
}

#------------#
sub _disable {
#------------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $flagfile = $self->{flagfile};

    if ( -f $flagfile ) {
        return 1;
    }

    $logger->info("disabling collector");

    unless ( open FH, ">$flagfile" ) {
        $logger->error("cannot create $flagfile: $!");
        return;
    }

    close(FH);
 
    $logger->info("collector disabled");
    
    return 1;
}

#-----------#
sub _enable {
#-----------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $flagfile = $self->{flagfile};

    unless ( -f $flagfile ) {
        return 1;
    }

    $logger->info("enabling collector");

    unless ( unlink( $flagfile ) ) {
        $logger->error("$flagfile cannot be removed");
        return;
    }

    $logger->info("collector enabled");

    return 1;
}


#---------------#
sub is_disabled {
#---------------#
    my ( $self ) = @_;


    if ( $self->{status} eq $STATUS_DISABLED ) {
        return $HARD_DISABLED;
    }

    if ( -f $self->{flagfile} ) {
        return $SOFT_DISABLED;
    }

    return 0;
}


#--------------------#
sub is_hard_disabled {
#--------------------#
    my ( $self ) = @_;


    if ( $self->{status} eq $STATUS_DISABLED ) {
        return $HARD_DISABLED;
    }

    return 0;
}


#---------#
sub check {
#---------#
    my ( $self ) = @_;


    if ( $self->{status} eq $STATUS_DISABLED ) {
        return;
    }

    my $logger     = $self->{logger};
    my $config     = $self->{config};
    my $process    = $self->{process}; 
    my $pidfile    = $self->{pidfile};
    my $descriptor = $self->{descriptor};

    if ( $self->{status} eq $STATUS_RUNNING and $process and $process->is_still_running() ) {
        return 1;
    }

    unless ( $pidfile and -f $pidfile ) { 
        $logger->info("pidfile $pidfile not found, collector is not running");
        $self->{process} = undef;
        $self->{status}  = $STATUS_STOPPED;
        return;
    } 

    unless ( $process = Mx::Process->new( pidfile => $pidfile, descriptor => $descriptor, logger => $logger, config => $config ) ) {
        $logger->warn("$pidfile present, but no running process");
        unless ( unlink( $pidfile ) ) {
            $logger->error("$pidfile cannot be removed");
        }
        $self->{process} = undef;
        $self->{status}  = $STATUS_STOPPED;
        return;
    }

    $self->{process}  = $process;
    $self->{hostname} = $process->hostname;
    $self->{status}   = $STATUS_RUNNING;

    return 1;
}

#--------#
sub list {
#--------#
    my ($class, %args) = @_;

 
    my @collectors = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    $logger->debug('scanning the configuration file for collectors');

    my $collectors_ref;
    unless ( $collectors_ref = $config->COLLECTORS ) {
        $logger->logdie("cannot access the collectors section in the configuration file");
    }

    my $location = $args{location};

    foreach my $name (keys %{$collectors_ref}) {
        my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
        next if ( defined $location and $collector->{location} != $location );
        push @collectors, $collector;
    }

    return @collectors;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#------------#
sub location {
#------------#
    my ( $self ) = @_;

    return $self->{location};
}

#------------#
sub hostname {
#------------#
    my ( $self ) = @_;

    return $self->{hostname};
}

#---------#
sub order {
#---------#
    my ( $self ) = @_;

    return $self->{order};
}

#-----------#
sub process {
#-----------#
    my ( $self ) = @_;

    return $self->{process};
}

#--------#
sub path {
#--------#
    my ( $self ) = @_;

    return $self->{path};
}

#-----------#
sub logfile {
#-----------#
    my ( $self ) = @_;

    return $self->{logfile};
}

#-----------#
sub pidfile {
#-----------#
    my ( $self ) = @_;

    return $self->{pidfile};
}

#-----------#
sub rrdfile {
#-----------#
    my ( $self ) = @_;

    return $self->{rrdfile};
}

#-----------------#
sub hires_rrdfile {
#-----------------#
    my ( $self ) = @_;

    return $self->{hires_rrdfile};
}

#------------#
sub rrdfile2 {
#------------#
    my ( $self ) = @_;

    return $self->{rrdfile2};
}

#---------------#
sub description {
#---------------#
    my ( $self ) = @_;

    return $self->{description};
}

#--------------#
sub descriptor {
#--------------#
    my ( $self ) = @_;

    return $self->{descriptor};
}

#-----------------#
sub poll_interval {
#-----------------#
    my ( $self ) = @_;

    return $self->{poll_interval};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;

    return $self->{status};
}

#----------------------------#
sub init_disabled_collectors {
#----------------------------#
    my ( $class, %args ) = @_;


    my @disabled_collectors = ();

    my $config = $args{config} or croak "missing argument 'config'";

    my $ref = $config->retrieve( 'DISABLE_COLLECTOR', 1 );

    if ( $ref ) {
        if ( ref($ref) eq 'ARRAY' ) {
            @disabled_collectors = @{$ref};
        }
        else {
            @disabled_collectors = ( $ref );
        }
    }

    @DISABLED_COLLECTORS = @disabled_collectors;
}

#-----------------------------#
sub prepare_for_serialization {
#-----------------------------#
    my ( $self ) = @_;


    $self->{logger} = undef;
    $self->{config} = undef;
    if( $self->{process} ) {
        $self->{process}->prepare_for_serialization;
    }
}

#-------------------------------#
sub unprepare_for_serialization {
#-------------------------------#
    my ( $self, %args ) = @_;


    $self->{config} = $args{config};
    $self->{logger} = Mx::Log->new( filename => $self->{logfile} );
}

#--------------#
sub rotate_log {
#--------------#
    my ( $self ) = @_;


    $self->{logger}->rotate();
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;


    my %info = (
      0  => $self->{name},
      1  => $self->{order},
      2  => $self->{location},
      3  => $self->{hostname},
      4  => $self->{status},
      5  => $self->{description},
      6  => '',
      7  => '',
      8  => '',
      9  => '',
      10 => '',
      11 => '',
      12 => '',
      13 => '',
      14 => '',
      15 => '',
      DT_RowId => $self->{name} . '|' . $self->{logfile}
    );

    if ( my $process = $self->{process} ) {
      $info{6}  = $process->pid;
      $info{7}  = $process->process_model;
      $info{8}  = Mx::Util->convert_time( $process->starttime );
      $info{9}  = $process->pcpu;
      $info{10} = $process->pmem;
      $info{11} = Mx::Util->separate_thousands( $process->vsz );
      $info{12} = Mx::Util->separate_thousands( $process->rss );
      $info{13} = Mx::Util->separate_thousands( $process->cputime );
      $info{14} = Mx::Util->separate_thousands( $process->nlwp );
      $info{15} = Mx::Util->separate_thousands( $process->nfh );
    }

    return \%info;
}

1;
