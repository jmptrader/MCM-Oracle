package Mx::Service;

# Fields
#
# name:              name of the service, for example 'fileserver'
# launcher:          full path to launchmxj.app
# options:           options needed to start the service via launchmxj.app, for example '-fs'
# params:            optional additional parameters (e.g. /MXJ_CONFIG_FILE:....)
# location:          index number for @app_servers
# hostname:          host where the service is running
# descriptor:        unique string which is used in the output of launchmxj.app -s (there might be more than one descriptor per service)
# nr_descriptors:    the number of descriptors for this service
# order:             relative order in which the services should be started
# post_start_action: action which must be performed after the service is started
# pre_stop_action:   action which must be performed before the service is stopped
# status:            state of the service (STARTING, STARTED,...) (there might be more than one process per service - namely one per descriptor)
# manual:            indicates that the service must be manually started (it does not start automatically during a full start)
# process:           corresponding Mx::Process object
#

use strict;
use warnings;

use Carp;
use Cwd;
use File::Basename;
use IO::File;
use Fcntl qw( :seek );
use Mx::Config;
use Mx::Process;
use Mx::Util;

my $LAUNCHER = 'launchmxj.app';

use constant START_DELAY   => 5;
use constant STOP_DELAY    => 5;

use constant START_TIMEOUT => 60;

use constant UNKNOWN       => 1;
use constant STARTED       => 2;
use constant STOPPED       => 3;
use constant FAILED        => 4;
use constant DISABLED      => 5;

my %STATUS = (
  1   => 'unknown',
  2   => 'started',
  3   => 'stopped',
  4   => 'failed',
  5   => 'disabled',
);

#
# Used to instantiate a service
#
# Arguments:
#  name:   name of the service
#  config: a Mx::Config instance
#  logger: a Mx::Log instance
#
#-------#
sub new {
#-------#
    my ($class, %args) = @_;


    my $self = {};

    my $logger = $self->{logger} = $args{logger} or croak 'no logger defined';

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex service (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex service (config)");
    }

    my $service_ref;
    unless ( $service_ref = $config->retrieve("SERVICES.$name") ) {
        $logger->logdie("service '$name' is not defined in the configuration file");
    }

    foreach my $param (qw(project launcher options descriptor label order dependency pattern logpattern params location post_start_action post_start_desc pre_stop_action pre_stop_desc start_delay nr_start_retries)) {
        unless ( exists $service_ref->{$param} ) {
            $logger->logdie("parameter '$param' for service '$name' is not defined in the configuration file");
        }
        $self->{$param} = $service_ref->{$param};
    }

    #
    # check if the location is properly defined
    #
    my $location_nr; my $location_range = '';
    unless ( ( $location_nr, $location_range ) = $self->{location} =~ /^(\d+)(\+?)$/ ) {
        $logger->logdie('wrong location specified: ', $self->{location});
    }

    my $location = $args{location};

    if ( defined $location ) {
        if ( $location_range ) {
            return unless $location >= $location_nr;
            $self->{location} = $location;
        }
        else {
            return unless $location == $location_nr;
        }
    }
    else {
        if ( $location_range ) {
            $logger->logdie("a service with a location range cannot be initialized without location argument");
        }
    }

    #
    # If there is only one descriptor, we still make an array out of it
    #
    unless ( ref( $self->{descriptor} ) eq 'ARRAY' ) {
        $self->{descriptor} = [ $self->{descriptor} ];
        $self->{label}      = [ $self->{label} ];
        $self->{pattern}    = [ $self->{pattern} ];
        $self->{logpattern} = [ $self->{logpattern} ];
    }
    $self->{nr_descriptors} = @{$self->{descriptor}};

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
    my $app_srv_short = Mx::Util->hostname( $app_servers[ $self->{location} ] );

    map { $_ =~ s/__APP_SRV_SHORT__/$app_srv_short/g } @{$self->{descriptor}};
    $self->{params} =~ s/__APP_SRV_SHORT__/$app_srv_short/g;

    my @logfiles; my @pidfiles;
    foreach my $descriptor ( @{$self->{descriptor}} ) {
        my ( $logfile, $pidfile ) = _log_and_pidfile( $name, $descriptor, $self->{project}, $config );
        push @logfiles, $logfile; 
        push @pidfiles, $pidfile; 
    }

    $self->{logfile} = [ @logfiles ];
    $self->{pidfile} = [ @pidfiles ];

    #
    # determine the full path to the 'launcher'
    #
    if ( $self->{launcher} ) {
        if ( $self->{project} && substr( $self->{launcher}, 0, 1 ) ne '/' ) {
            my $hash = $config->get_project_variables( $self->{project} );
            $self->{launcher} = $hash->{PROJECT_BINDIR} . '/' . $self->{launcher};
        } 
    }
    elsif ( $name eq 'docserver' ) {
        $self->{launcher} = $config->MXENV_ROOT . '/mxdoc_fs/' . $LAUNCHER;
    }
    else {
        $self->{launcher} = $config->MXENV_ROOT . '/' . $LAUNCHER;
    }

    unless ( -f $self->{launcher} ) {
        $logger->error('cannot find launcher ', $self->{launcher});
    }

    my @disabled_services = $config->retrieve_as_array( 'DISABLE_SERVICE', 1 );

    $self->{status} = ( grep /^$name$/, @disabled_services ) ? DISABLED : UNKNOWN;

    if ( grep /^$name:no_post$/, @disabled_services ) {
        $self->{post_start_action} = undef;
    }

    my @manual_services = $config->retrieve_as_array( 'MANUAL_SERVICE', 1 );

    $self->{manual} = ( grep /^$name$/, @manual_services ) ? 1 : 0;

    $self->{process}         = [];
    $self->{process_by_desc} = {};
    $self->{start_delay} ||= START_DELAY;

#    $logger->debug("service '$name' initialized");

    bless $self, $class;
}

#
# Returns a ordered list of all Mx::Service objects that can be found in the configuration file
# 
# Arguments:
#   config: a Mx::Config instance
#   logger: a Mx::Log instance
#
#--------#
sub list {
#--------#
    my ($class, %args) = @_;


    my @services;

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );

#    $logger->debug('scanning the configuration file for services');

    my $services_ref;
    unless ( $services_ref = $config->SERVICES ) {
        $logger->logdie("cannot access the services section in the configuration file");
    }

    my $order = 1;
    foreach my $name (keys %{$services_ref}) {
        if ( $args{name} and $args{name} ne $name ) {
            next;
        }

        my $service_location = $services_ref->{$name}->{location};

        my $location_nr; my $location_range = '';
        unless ( ( $location_nr, $location_range ) = $service_location =~ /^(\d+)(\+?)$/ ) {
            $logger->logdie('wrong location specified: ', $service_location);
        }

        my @locations = ();
        if ( defined $args{location} ) {
            @locations = ( $args{location} );
        }
        elsif ( ! $location_range ) {
            @locations = ( $location_nr );
        }
        else {
            @locations = ( $location_nr .. $#app_servers );
        }

        foreach my $location ( @locations ) {
            next unless $app_servers[$location];

            if ( my $service = Mx::Service->new( name => $name, location => $location, config => $config, logger => $logger ) ) {
                push @services, $service;
            }
        }
    }

    my $nr_services = @services;
#    $logger->debug("found $nr_services services in the configuration file");

    @services = sort { $a->{order} <=> $b->{order} } @services;

    return @services;
}

#
# This class method takes as argument a list of Mx::Service objects and updates the status and process fields.
# One prerequisite: all services should belong to the same environment.
#
#----------#
sub update {
#----------#
    my ($class, %args) = @_;


    my @list;
    unless ( @list = @{$args{list}} ) {
        croak 'no arguments';
    }

    #
    # 'borrow' the logger, config, and launcher from the first object in the list
    #
    my $service = $list[0];
    unless ( ref($service) eq 'Mx::Service' ) {
        croak 'only Mx::Service objects are allowed as arguments';
    }
    my $logger = $service->{logger};
    my $config = $service->{config};

    my $hostname = Mx::Util->hostname();

    #
    # for every service, lookup the corresponding proces(ses)
    #
    foreach my $service (@list) {
        unless ( ref($service) eq 'Mx::Service' ) {
            $logger->logdie('only Mx::Service objects are allowed as arguments');
        }

        $service->{hostname} = $hostname;

        if ( $service->{status} == DISABLED ) {
#            $logger->debug("service '$name' is disabled");
            next;
        }

        my $name                = $service->{name};
        my $project             = $service->{project};
        my $descriptor_ref      = $service->{descriptor};
        my $process_ref         = $service->{process};
        my $process_by_desc_ref = $service->{process_by_desc};
        my $label_ref           = $service->{label};
        my $pattern_ref         = $service->{pattern};
        my $logpattern_ref      = $service->{logpattern};
        my $logfile_ref         = $service->{logfile};
        my $pidfile_ref         = $service->{pidfile};
        my $nr_descriptors      = $service->{nr_descriptors};

        my $nr_processes = 0;
        for ( my $i = 0; $i < $nr_descriptors; $i++ ) {
            my $descriptor = $descriptor_ref->[$i];
            my $process    = $process_ref->[$i];
            my $label      = $label_ref->[$i];
            my $pattern    = $pattern_ref->[$i];
            my $logpattern = $logpattern_ref->[$i];
            my $logfile    = $logfile_ref->[$i];
            my $pidfile    = $pidfile_ref->[$i];

            if ( $process ) {
                my $rc = $process->check_pidfile();

                if ( $rc == 1 ) {
                    if ( $process->is_still_running ) {
                        $process->update_performance();
                        $nr_processes++;
                    }
                    else {
                        $logger->warn("descriptor $descriptor has no corresponding process");
                        $process_ref->[$i] = undef;
                        $process_by_desc_ref->{$descriptor} = undef;
                    }
                }
                elsif ( $rc == 2 ) {
                    $process->update_performance();
                    $nr_processes++;
                }
                else {
                    $logger->warn("descriptor $descriptor has no corresponding process");
                    $process_ref->[$i] = undef;
                    $process_by_desc_ref->{$descriptor} = undef;
                }
            }
            elsif ( -f $pidfile ) {
                if ( $process = Mx::Process->new( pidfile => $pidfile, hostname => $hostname, logger => $logger, config => $config, pattern => $pattern ) ) {
                    $process->update_performance();
                    $process->descriptor( $descriptor );
                    $process->label( $label );
                    $nr_processes++;
                    $process_ref->[$i] = $process;
                    $process_by_desc_ref->{$descriptor} = $process;
                }
                else {
                    $logger->warn("$pidfile contains an old PID");
#                    if ( unlink $pidfile ) {
#                        $logger->info("$pidfile removed");
#                    }
                }
            }
        }

        if ( $nr_descriptors == $nr_processes ) {
            $service->{status} = STARTED;
        }
        elsif ( $nr_processes == 0 ) {
            $service->{status} = STOPPED;
#            $logger->debug("service '$name' is not running");
        }
        else {
            $service->{status} = FAILED;
            $logger->error("service '$name' is corrupted: there should be $nr_descriptors processes running, but only $nr_processes processes are detected");
        }
    }
}

#---------#
sub start {
#---------#
    my ($self, %args) = @_;

   
    my $logger         = $self->{logger};
    my $config         = $self->{config};
    my $name           = $self->{name};
    my $apache_request = $args{apache_request};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in service start (db_audit)");
    }

    my $service_id;
    my $starttime = time();

    $logger->debug("starting service '$name'");

    if ( $self->{status} == UNKNOWN ) {
        Mx::Service->update( list => [ $self ] );
    }
    unless ( $self->{status} == STOPPED ) {
        $logger->warn("trying to start a service ($name) which is not stopped");
        return 1;
    }

    #
    # enable GC logging if necessary
    #
    my $gc_args = '';
    if ( $name ne 'docserver' && $config->retrieve('ENABLE_GC_LOGGING', 1) ) {
        foreach my $descriptor ( @{$self->{descriptor}} ) {
            my $gclog = $config->retrieve('GCLOGDIR') . '/' . $descriptor . '.gc';
            Mx::Log->rotate( filename => $gclog ) if -f $gclog;
        }
        $gc_args = '-j:-Xloggc:' . $config->retrieve('GCLOGDIR') . '/__LOG_FILE__.gc';
    }

    my $command;
    if ( $self->{launcher} =~ /$LAUNCHER/ ) {
        $command = $self->{launcher} . ' ' . $self->{options} . ' ' . $self->{params} . ' -jopt:-Dmcm=true ' . $gc_args;
    }
    else {
        $command = $self->{launcher} . ' -start ' . $self->{options} . ' ' . $self->{params};
    }

    my $nr_start_retries = $self->{nr_start_retries} || 0;
    my $successfully_started = 0;

    while ( $nr_start_retries >= 0 ) {
        my @logfiles = _loginfo( $self->{logfile}, $self->{logpattern}, $logger );

        my ( $success, undef, undef, undef, $duration ) = Mx::Process->run( command => $command, logger => $logger, config => $self->{config}, directory => dirname($self->{launcher}), apache_request => $apache_request, db_audit => $db_audit );

        _logcheck( \@logfiles, START_TIMEOUT, $logger ) if $success;

        Mx::Service->update( list => [ $self ] );

        if ( $self->{status} == STARTED ) {
            $logger->info("service '$name' is successfully started");
            $service_id = $db_audit->record_service_start( name => $name, starttime => $starttime, duration => $duration, rc => 0, processes => $self->{process} );
            $successfully_started = 1;
            last;
        }

        $logger->error("starting of service '$name' failed");
        $service_id = $db_audit->record_service_start( name => $name, starttime => $starttime, duration => $duration, rc => 1, processes => $self->{process} );
        $nr_start_retries--;
    }

    if ( ! $successfully_started ) {
        $logger->error("starting of service '$name' failed");
        return 0;
    }

    if ( my $action = $self->{post_start_action} ) {
        $logger->info("executing post-start action: $action");

        my $success; my $duration;
        if ( $action =~ /&\s*$/ ) {
            $action =~ s/&\s*$//;

            $duration = time();
            my $process = Mx::Process->background_run( command => $action, logger => $logger, config => $self->{config}, directory => dirname($self->{launcher}), ignore_child => 1 );
            $duration = time() - $duration;

            $success = ( $process ) ? 1 : 0;
        }
        else {
            ( $success, undef, undef, undef, $duration ) = Mx::Process->run( command => $action, logger => $logger, config => $self->{config}, directory => dirname($self->{launcher}), timeout => 600, apache_request => $apache_request );
        }

        my $rc;
        if ( $success ) {
            $logger->info("post-start action completed successfully");
            $rc = 0;
        }
        else {
            $logger->error("post-start action failed");
            $rc = 1;
        }

        $db_audit->record_post_start( service_id => $service_id, duration => $duration, rc => $rc );

        return $success;
    }

    return 1;
}

#--------#
sub stop {
#--------#
    my ($self, %args) = @_;


    my $logger = $self->{logger};
    my $name   = $self->{name};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in service stop (db_audit)");
    }

    $logger->debug("stopping service '$name'");

    my $service_id = $db_audit->retrieve_live_service_via_name( name => $name );

    if ( $self->{status} == UNKNOWN ) {
        Mx::Service->update( list => [ $self ] );
    }
    unless ( $self->{status} == STARTED or $self->{status} == FAILED ) {
        $logger->warn("trying to stop a service ($name) which is not running");
        return 1;
    }

    my @processes = @{$self->{process}};

    if ( my $action = $self->{pre_stop_action} ) {
        $logger->info("executing pre-stop action: $action");

        my ( $success, undef, undef, undef, $duration ) = Mx::Process->run(command => $action, logger => $logger, config => $self->{config}, directory => dirname($self->{launcher}), timeout => 300 );

        my $rc;
        if ( $success ) {
            $logger->info("pre-stop action completed successfully");
            $rc = 0;
        }
        else {
            $logger->error("pre-stop action failed");
            $rc = 1;
        }

        $db_audit->record_pre_stop( service_id => $service_id, duration => $duration, rc => $rc ) if $service_id;
    }

    my $command;
    if ( $self->{launcher} =~ /$LAUNCHER/ ) {
        $command = $self->{launcher} . ' ' . $self->{options} . ' -k ' . $self->{params};
    }
    else {
        $command = $self->{launcher} . ' -stop ' . $self->{options} . ' ' . $self->{params};
    }

    my ( $success, undef, undef, undef, $duration ) = Mx::Process->run(command => $command, logger => $logger, config => $self->{config}, directory => dirname($self->{launcher}));

    sleep STOP_DELAY;

    Mx::Service->update( list => [ $self ] );

    my $rc; my $rv;
    if ( $self->{status} == STOPPED ) {
        $logger->info("service '$name' is successfully stopped");
        $rc = 0; $rv = 1;
    }
    else {
        $logger->error("stopping of service '$name' failed");
        $rc = 1; $rv = 0;
    }

    $db_audit->record_service_stop( service_id => $service_id, endtime => time(), duration => $duration, rc => $rc, processes => [ @processes ] ) if $service_id;

    return $rv;
}

#--------#
sub name {
#--------#
    my ($self) = @_;

    return $self->{name};
}

#------------#
sub hostname {
#------------#
    my ($self) = @_;

    return $self->{hostname};
}

#----------#
sub status {
#----------#
    my ($self) = @_;

    return $STATUS{$self->{status}};
}

#----------#
sub manual {
#----------#
    my ($self) = @_;

    return $self->{manual};
}

#-----------#
sub project {
#-----------#
    my ($self) = @_;

    return $self->{project};
}

#---------#
sub order {
#---------#
    my ($self) = @_;

    return $self->{order};
}

#--------------#
sub dependency {
#--------------#
    my ($self) = @_;

    return $self->{dependency};
}

#----------#
sub params {
#----------#
    my ($self) = @_;

    return $self->{params};
}

#-----------#
sub options {
#-----------#
    my ($self) = @_;

    return $self->{options};
}

#---------------#
sub descriptors {
#---------------#
    my ($self) = @_;

    return @{$self->{descriptor}};
}

#------------#
sub location {
#------------#
    my ($self) = @_;

    return $self->{location};
}

#---------------------#
sub post_start_action {
#---------------------#
    my ($self) = @_;

    return $self->{post_start_action};
}

#-------------------#
sub post_start_desc {
#-------------------#
    my ($self) = @_;

    return $self->{post_start_action};
}

#-------------------#
sub pre_stop_action {
#-------------------#
    my ($self) = @_;

    return $self->{pre_stop_action};
}

#-----------------#
sub pre_stop_desc {
#-----------------#
    my ($self) = @_;

    return $self->{pre_stop_desc};
}

#-------------#
sub processes {
#-------------#
    my ($self) = @_;

    return @{$self->{process}};
}

#-----------#
sub process {
#-----------#
    my ( $self, %args ) = @_;


    if ( ( my $descriptor = $args{descriptor} ) && ( ref( $self->{process_by_desc} ) eq 'HASH' ) ) {
        return $self->{process_by_desc}->{$descriptor};
    }
}

#----------#
sub labels {
#----------#
    my ($self) = @_;

    return @{$self->{label}};
}

#-----------------------------#
sub prepare_for_serialization {
#-----------------------------#
    my ( $self ) = @_;


    $self->{logger} = undef;
    $self->{config} = undef;
    if ( $self->{process} ) {
        foreach my $process ( @{$self->{process}} ) {
            $process->prepare_for_serialization( exclude_cmdline => 0 ) if $process;
        }
    }
}  

#-------------------------------#
sub unprepare_for_serialization {
#-------------------------------#
    my ( $self, %args ) = @_;


    $self->{logger} = $args{logger};
    $self->{config} = $args{config};
    if ( $self->{process} ) {
        foreach my $process ( @{$self->{process}} ) {
            $process->unprepare_for_serialization( %args ) if $process;
        }
    }
}

#----------------#
sub check_access {
#----------------#
    my ($class, $config, $logger) = @_;

    my $flag = $config->RUNDIR . '/.disabled';
    return ( -f $flag ) ? 0 : 1;
}

#-----------------#
sub enable_access {
#-----------------#
    my ($class, $config, $logger) = @_;

    my $flag = $config->RUNDIR . '/.disabled';
    $logger->debug('enabling access to Murex');
    if ( -f $flag ) {
        unless ( unlink($flag) ) {
            $logger->error("cannot remove $flag to enable access to Murex: $!");
            return 0;
        }
        $logger->debug('access enabled');
        return 1;
    }
    else {
        $logger->debug("no flag file ($flag) found, access is already enabled");
        return 1;
    } 
}
     
#------------------#
sub disable_access {
#------------------#
    my ($class, $config, $logger) = @_;

    my $flag = $config->RUNDIR . '/.disabled';
    $logger->debug('disabling access to Murex');
    if ( -f $flag ) {
        $logger->debug("flag file ($flag) found, access is already disabled");
        return 1;
    }
    else {
        unless ( IO::File->new( $flag, '>' ) ) {
            $logger->error("cannot create $flag to disable access to Murex: $!");
            return 0;
        }
        $logger->debug('access disabled');
        return 1;
    } 
}

#--------------------#
sub _log_and_pidfile {
#--------------------#
    my ( $name, $descriptor, $project, $config ) = @_;


    my $rundir; my $logdir;
    if ( $project ) {
        my $date = Mx::Murex->calendardate();
        $logdir = $config->retrieve_project_logdir( $project ) . '/' . $date;
        $rundir = $config->retrieve_project_rundir( $project );
    }
    elsif ( $name eq 'docserver' ) {
        $logdir = $rundir = $config->MXENV_ROOT . '/mxdoc_fs/logs';
    }
    else {
        $logdir = $rundir = $config->MXENV_ROOT . '/logs';
    }

    my $logfile = $logdir . '/' . $descriptor . '.log';
    my $pidfile = $rundir . '/' . $descriptor . '.pid';

    return ( $logfile, $pidfile );
}

#------------#
sub _loginfo {
#------------#
    my ( $logfiles, $logpatterns, $logger ) = @_;


    my @info = ();

    my $i = 0;
    foreach my $path ( @{$logfiles} ) {
        my %info = ();
        $info{path}    = $path;
        $info{started} = 0;
        $info{pattern} = $logpatterns->[$i++];

        if ( -f $path ) { 
            $info{present} = 1;
            $info{size}    = -s $path;

            unless ( open( FH, "< $path" ) ) {
                $logger->logdie("cannot open $path: $!");
            }
            seek( FH, 0, SEEK_END );
            $info{position} = tell( FH );
            close(FH);
        }
        else {
            $info{present}  = 0;
            $info{size}     = 0;
            $info{position} = 0;
        }

        push @info, { %info }; 
    }

    return @info;
}

#-------------#
sub _logcheck {
#-------------#
    my ( $logfiles, $timeout, $logger ) = @_; 


    my $nr_logfiles = @{$logfiles};
    my $nr_started  = 0;

    my $latest = time() + $timeout;

    while ( time() < $latest ) {
        foreach my $logfile ( @{$logfiles} ) {
            next if $logfile->{started};

            my $path = $logfile->{path};

            if ( ! $logfile->{present} ) {
                ( -f $path ) ? $logfile->{present} = 1 : next;
            }

            my $size = -s $path;

            next if $size == $logfile->{size};

            unless ( open( FH, "< $path" ) ) {
                $logger->error("cannot open $path: $!");
            }

            seek( FH, $logfile->{position}, SEEK_SET );

            my $text; my $buffer;
            while ( read( FH, $buffer, 2000 ) ) {
                $text .= $buffer;
            }

            $logfile->{position} = tell( FH );
            $logfile->{size}    += length( $text ); 

            close(FH);

            my $pattern = $logfile->{pattern};

            if ( $text =~ /$pattern/m ) {
                $logfile->{started} = 1;
                $nr_started++;
                $logger->debug("$path reports that the service is ready");
            }
        }

        last if $nr_logfiles == $nr_started;

        sleep 1;
    }

    if ( $nr_logfiles != $nr_started ) {
        $logger->error("timeout ($timeout) reached, not all logfiles are ok");
        return 0;
    }

    return 1;
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self, %args ) = @_;


    my %base_info = (
      0  => $self->{name},
      1  => $self->{order},
      2  => $self->{location},
      3  => $self->{hostname},
      4  => $STATUS{$self->{status}},
      5  => '',
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
      16 => ( $self->{manual} ) ? 'manual' : 'auto',
      17 => $self->{project} || '',
      18 => '',
      19 => '',
      20 => '',
      21 => '',
      22 => '',
      23 => '',
      24 => '',
      DT_RowId => $self->{name}
    );

    my @list; my $i = 0;
    foreach my $descriptor ( @{$self->{descriptor}} ) {
        my %info = %base_info;

        my $starttime = time(); my $mxres = '';
        if ( my $process = $self->{process}->[$i] ) {
            $info{5}  = $process->label;
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
            my ( $xms, $xmx ) = $process->java_xms;
            $info{18} = Mx::Util->separate_thousands( $xms );
            $info{19} = Mx::Util->separate_thousands( $xmx );

            if ( $args{gc} && ( my %gc = $process->last_gc() ) ) {
                $info{20} = Mx::Util->separate_thousands( $gc{total_size} );
                $info{21} = sprintf "%.2f", $gc{total_size} / $xmx * 100;
                $info{22} = Mx::Util->separate_thousands( $gc{total_gcs} );
                $info{23} = Mx::Util->separate_thousands( $gc{total_full_gcs} );
            }

            $info{24} = ( $process->mcm_started || ( $self->{launcher} !~ /$LAUNCHER/ ) ) ? 'YES' : 'NO';

            $starttime = $process->starttime;
            if ( $mxres = $process->mxres ) {
                $mxres =~ s/\.(?!mxres$)/\//g;
                $mxres = $self->{config}->MXENV_ROOT . '/fs/' . $mxres;
            }
        }

        $info{DT_RowId} = $self->{name} . '|' . $self->{location} . '|' . $descriptor . '|' . $info{17} . '|' . Mx::Murex->calendardate( $starttime ) . '|' . $starttime . '|' . $mxres;

        push @list, { %info };

        $i++;
    }

    return @list;
}

#------------------------#
sub check_no_full_stop   {
#------------------------#
#

    my ($self, %args) = @_;

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
      $logger->logdie("missing argument (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
      $logger->logdie("config argument is not of type Mx::Config");
    }

    my $rc = 0 ;

    my ( $sec, $min, $hour, $mday, $mon, $year, $current_day ) = localtime( time() );
    my $current_time = $hour * 3600 + $min * 60 ;

    my $latest_full_stop_time = $config->LATEST_FULL_STOP_TIME ;

    if ( $latest_full_stop_time =~ /^(\d+):(\d+)$/ ) {
       my $hour = $1;
       my $min  = $2;
       unless ( $hour <= 23 and $min <= 59 ) {
         $logger->logdie("Wrong latest_full_stop_time specified: $latest_full_stop_time");
       }
       $latest_full_stop_time = $hour * 3600 + $min * 60 ;

    } else {
       $logger->logdie("Wrong latest_full_stop_time format");
    }

    if ( $current_time >= $latest_full_stop_time ) {
      $logger->warn("Latest full stop time past, no Murex start/stop allowed.") ;
      $rc = 1;
    }

    return $rc ;
    
}

1;

__END__

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    

# Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

					    
=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT


A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

					
=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.


=head1 AUTHOR

<Author name(s)>

