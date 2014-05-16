package Mx::Secondary;

use strict;
use warnings;

use Mx::Process;
use Mx::Service;
use Mx::Collector;
use Mx::System;
use SOAP::Lite;
use Mx::Util;
use Mx::DBaudit;
use IO::File;
use Mx::Filesystem;
use Mx::FileSync;
use IPC::ShareLite qw( :lock );
use IPC::Shareable;
use Storable qw( freeze thaw );
use Carp;

our $sec_logger;
our $config;
our $webhandle;
our %services;
our %collectors;
our %sessions;
our $instance;
our $starttime;
our $pid;

my %SHARES       = ();
my $SHARE_HANDLE = undef;
my $SHARE_EXPIRY = 3600;

require Solaris::loadavg if Mx::Process->ostype eq 'solaris';


#--------#
sub init {
#--------#
    my ( $class, %args ) = @_;


    no warnings 'once';

    $starttime = time();
    $pid = $$;

    *SOAP::Serializer::as_string = \&SOAP::XMLSchema2001::Serializer::as_base64Binary;

    $sec_logger = $args{logger} or croak 'no logger defined.';

    unless ( $config = $args{config} ) {
        $sec_logger->logdie("missing argument in initialisation of secondary handle (config)");
    }

#    $ENV{IPC_SHARELITE_LOG} = $sec_logger->filename();
#    $ENV{SHAREABLE_DEBUG}   = 1;

    $instance = $args{instance};

    if ( defined $instance ) {
        $SHARE_HANDLE = tie %SHARES, 'IPC::Shareable', $<, { create => 1 };
    }
}

#
# Arguments
#
# instance     an integer indicating which secondary to connect to (default is 1)
# webhandle    Mason request object if the connection is made from the webserver
# timeout
# config
# logger
#
#----------#
sub handle {
#----------#
    my ( $class, %args ) = @_;


    my $self = {};

    $sec_logger = $args{logger} or croak 'no logger defined.';
    unless ( $config = $args{config} ) {
        $sec_logger->logdie("missing argument in initialisation of secondary handle (config)");
    }
   
    unless ( $sec_logger and $config ) {
        croak 'no logger of config defined';
    }

    $webhandle = $args{webhandle};

    my $instance = $args{instance};
    my $hostname = $args{hostname};

    unless ( $instance =~ /^(\d+)$/ ) {
        $sec_logger->logdie("wrong instance specified ($instance)");
    }

    unless ( $hostname ) {
        my @app_servers = $config->retrieve_as_array( 'APP_SRV' );

        $hostname = $app_servers[$instance];
    }

    my $portnumber = $config->retrieve( 'SECONDARY_MON_PORT', 1 );

    $self->{instance}         = $instance;
    $self->{hostname}         = $hostname;
    $self->{batch_nick}       = ($config->retrieve_as_array( 'BATCH_NICK' ))[$instance];
    $self->{batch_handicap}   = ($config->retrieve_as_array( 'BATCH_HANDICAP' ))[$instance];
    $self->{session_nick}     = ($config->retrieve_as_array( 'SESSION_NICK' ))[$instance];
    $self->{session_handicap} = ($config->retrieve_as_array( 'SESSION_HANDICAP' ))[$instance];
    $self->{async_key}        = 0;
    $self->{disabled}         = 1;

    if ( $hostname && $portnumber ) {
        my $timeout = $args{timeout} || 0;

        if ( my $soaphandle = SOAP::Lite->uri( 'urn:/Mx/Secondary' )->proxy( "http://$hostname:$portnumber/", timeout => $timeout ) ) {
            $sec_logger->debug("secondary handle initialized with $hostname on port $portnumber");
            $soaphandle->on_fault( \&error_handler );
            $self->{soaphandle} = $soaphandle;
            $self->{disabled}   = 0;
        }
    }

    bless $self, $class;

    return $self;
}

#--------------#
sub soaphandle {
#--------------#
    my ( $self ) = @_;


    return $self->{soaphandle};
}

#------------#
sub instance {
#------------#
    my ( $self ) = @_;


    return $self->{instance};
}

#------------#
sub hostname {
#------------#
    my ( $self ) = @_;


    return $self->{hostname};
}

#------------------#
sub short_hostname {
#------------------#
    my ( $self ) = @_;


    return Mx::Util->hostname( $self->{hostname} );
}

#--------------#
sub batch_nick {
#--------------#
    my ( $self ) = @_;


    return $self->{batch_nick};
}

#------------------#
sub batch_handicap {
#------------------#
    my ( $self ) = @_;


    return $self->{batch_handicap};
}

#----------------#
sub session_nick {
#----------------#
    my ( $self ) = @_;


    return $self->{session_nick};
}

#--------------------#
sub session_handicap {
#--------------------#
    my ( $self ) = @_;


    return $self->{session_handicap};
}

#---------#
sub close {
#---------#
    my ( $self ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        $self->{soaphandle}->close();
    }
}

#-----------#
sub handles {
#-----------#
    my ( $class, %args ) = @_;


    my @handles = ();

    $sec_logger = $args{logger} or croak 'no logger defined.';
    unless ( $config = $args{config} ) {
        $sec_logger->logdie("missing argument in initialisation of secondary handle (config)");
    }
   
    unless ( $sec_logger and $config ) {
        croak 'no logger of config defined';
    }

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );

    my $instance = 0;
    foreach my $hostname ( @app_servers ) {
        push @handles, $class->handle( %args, instance => $instance++, hostname => $hostname );
    }

    return @handles;
}

#-----------------#
sub error_handler {
#-----------------#
    my ( $soap, $result ) = @_;


    my $message = ref $result ? $result->faultstring : $soap->transport->status;

    $sec_logger->error("cannot communicate with the secondary monitor: $message");

    if ( $webhandle ) {
        print "<CENTER>";
        print "<BR><BR><BR>";
        print "<H2>cannot communicate with the secondary monitor</H2>";
        print "($message)";
        print "</CENTER>";

        $webhandle->abort();
    }
    else {
        die "$message\n";
    }
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;


    my %info;

    $info{starttime} = $starttime;
    $info{pid} = $pid;

    return %info;
}

#----------------#
sub nr_instances {
#----------------#
    my ( $class ) = @_;


    my $nr_instances = $config->retrieve_as_array( 'APP_SRV' );

	return ( $nr_instances =~ /^\d+$/ ) ? $nr_instances : 1;
}

#------------#
sub sessions {
#------------#
    my ( $class, %args ) = @_;


    map { $_->{starttime} = 0 } values %sessions;

    my @sessions;
    foreach my $entry ( Mx::Process->thin_list() ) {
        my ( $pid, $starttime ) = @{$entry};

        my $process;
        if ( $process = $sessions{"$pid:$starttime"} ) {
            $process->update_performance();
        }
        else {
            if ( $process = Mx::Process->new( pid => $pid, logger => $sec_logger, config => $config ) ) {
                $sessions{"$pid:$starttime"} = $process;
            }
            else {
                next;
            }
        }

        push @sessions, $process if $process->type == $Mx::Process::MXSESSION;
    }

    foreach my $key ( keys %sessions ) {
        delete $sessions{$key} if $sessions{$key}->{starttime} == 0;
    }

    map { $_->prepare_for_serialization( exclude_cmdline => 1 ) } @sessions;

    return @sessions;
}

#------------------#
sub sessions_async {
#------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->sessions_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @sessions = Mx::Secondary->sessions( %args );

        my $value;
        eval { $value = freeze( \@sessions ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#------------------#
sub services_async {
#------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->services_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @services = Mx::Secondary->services( %args );

        my $value;
        eval { $value = freeze( \@services ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#------------------#
sub mservice_async {
#------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->mservice_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @services = Mx::Secondary->mservice( %args );

        my $value;
        eval { $value = freeze( \@services ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#--------------#
sub poll_async {
#--------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return () if $self->{disabled};

        my $key = $args{key} || $self->{async_key};

        unless ( $key ) {
            $sec_logger->error("poll using empty key");
            return ();
        }

        $self->{async_key} = 0;

        return $self->{soaphandle}->poll_async( key => $key, no_block => $args{no_block} )->paramsall;
    }

    my $key      = $args{key};
    my $no_block = $args{no_block};

    my $share;
    eval { $share = IPC::ShareLite->new( -key => $key, -create => 0, -destroy => 1 ); };

    if ( $@ ) {
        $sec_logger->error("cannot attach to a shared memory segment (key: $key): $@");
        return;
    }

    if ( $no_block ) {
        return () unless $share->lock( LOCK_EX|LOCK_NB );
    }
    else {
        $share->lock( LOCK_EX );
    }

    my $value;
    eval { $value = thaw( $share->fetch ); };

    if ( $@ ) {
        $sec_logger->error("cannot thaw a stored value: $@");
        return;
    }

    $share->unlock;

    undef $share;

    _unregister_share( key => $key );

    return @{$value};
}

#-------------------#
sub _register_share {
#-------------------#
    my ( %args ) = @_;


    my $key    = $args{key};
    my $expiry = time() + $SHARE_EXPIRY;

    if ( exists $SHARES{$key} ) {
        $sec_logger->error("trying to register a share with duplicate key (key: $key)");
        return;
    }

    $SHARE_HANDLE->shlock;
    
    $SHARES{$key} = $expiry;

    $SHARE_HANDLE->shunlock;

    return 1;
}

#---------------------#
sub _unregister_share {
#---------------------#
    my ( %args ) = @_;


    my $key = $args{key};

    unless ( exists $SHARES{$key} ) {
        $sec_logger->error("trying to unregister a unregistered share (key: $key)");
        return;
    }

    $SHARE_HANDLE->shlock;
    
    delete $SHARES{$key};

    $SHARE_HANDLE->shunlock;

    return 1;
}

#------------------#
sub _cleanup_share {
#------------------#
    my ( %args ) = @_;


    my $key = $args{key};

    $sec_logger->debug("cleaning up share $key");

    my $share;
    eval { $share = IPC::ShareLite->new( -key => $key, -create => 0, -destroy => 1 ); };

    if ( $@ ) {
        $sec_logger->error("cannot attach to a shared memory segment (key: $key): $@");
        return;
    }

    unless ( $share->lock( LOCK_EX|LOCK_NB ) ) {
        $sec_logger->error("cannot lock share (key: $key), aborting cleanup");
        return;
    }

    $share->unlock;

    undef $share;

    return 1;
}

#------------------#
sub cleanup_shares {
#------------------#
    my ( $class, %args ) = @_;


    my $current_time = time();
    my $nr_shares = 0;

    while ( my ( $key, $expiry ) = each %SHARES ) {
        next if $current_time < $expiry;

        if ( _cleanup_share( key => $key ) ) { 
            _unregister_share( key => $key );
            $nr_shares++;
        }
        else {
            $SHARE_HANDLE->shlock;

            $SHARES{$key} = $current_time + $SHARE_EXPIRY;

            $SHARE_HANDLE->shunlock;
        }
    }

    return $nr_shares;
}

#---------------#
sub list_shares {
#---------------#
    my ( $class, %args ) = @_;


    return %SHARES;
}

#-----------#
sub scripts {
#-----------#
    my ( $class, %args ) = @_;

    my @scripts;
    foreach my $process ( Mx::Process->list( logger => $sec_logger, config => $config ) ) {
        push @scripts, $process if ( $process->type == $Mx::Process::MXSCRIPT or $process->type == $Mx::Process::DMSCRIPT );
    }
    map { $_->prepare_for_serialization } @scripts;
    return @scripts;
}

#-----------------#
sub scripts_async {
#-----------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->scripts_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @scripts = Mx::Secondary->scripts( %args );

        my $value;
        eval { $value = freeze( \@scripts ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#-----------#
sub session {
#-----------#
    my ( $class, $pid, %args ) = @_;

    my $process = Mx::Process->new( pid => $pid, mxsession_id => $args{mx_sessionid}, logger => $sec_logger, config => $config, light => $args{light} );
    $process->prepare_for_serialization if $process;
    return $process;
}

#----------#
sub script {
#----------#
    my ( $class, $pid, %args ) = @_;

    my $process = Mx::Process->new( pid => $pid, logger => $sec_logger, config => $config, light => $args{light} );
    $process->prepare_for_serialization if $process;
    return $process;
}

#----------------#
sub kill_session {
#----------------#
    my ( $class, $pid, %args  ) = @_;

    if ( my $process = Mx::Process->new( pid => $pid, mx_sessionid => $args{mx_sessionid}, logger => $sec_logger, config => $config, light => 1 ) ) {
        return $process->kill() if $process;
    }
    return;
}

#---------------#
sub kill_script { 
#---------------#
    my ( $class, $pid, %args  ) = @_;

    if ( my $process = Mx::Process->new( pid => $pid, logger => $sec_logger, config => $config, light => 1 ) ) {
        return $process->kill() if $process;
    }
    return;
}

#-------------#
sub full_kill {
#-------------#
    my ( $class ) = @_;


    my $nr_killed = 0;
    foreach my $process ( Mx::Process->list( logger => $sec_logger, config => $config ) ) {
        if ( $process->type == $Mx::Process::MXSESSION or $process->type == $Mx::Process::MXSCRIPT or $process->type == $Mx::Process::MX_UNKNOWN or $process->type == $Mx::Process::JAVA_UNKNOWN ) {
            $nr_killed += $process->kill;
        }
    }

    return $nr_killed;
}

#-------------------#
sub full_kill_async {
#-------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->full_kill_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my $nr_killed = Mx::Secondary->full_kill( %args );

        my $value;
        eval { $value = freeze( [ $nr_killed ] ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#------------#
sub services {
#------------#
   my ( $class, %args ) = @_;


   my @services = Mx::Service->list( location => $instance, logger => $sec_logger, config => $config );

   Mx::Service->update( list => [ @services ] ) if @services;

   foreach my $service ( @services ) {
       my $name = $service->name;
       $services{$name} = $service;
   }

   map { $_->prepare_for_serialization } @services;

   return @services;
}

#------------#
sub mservice {
#------------#
   my ( $class, %args ) = @_;


   my @services = ();

   foreach my $name ( @{$args{names}} ) {
       my $service = $services{$name};
       if ( $service ) {
           $service->unprepare_for_serialization( logger => $sec_logger, config => $config );
       }
       else {
           $service = Mx::Service->new( name => $name, location => $instance, logger => $sec_logger, config => $config );
           $services{$name} = $service;
       }
       push @services, $service;
   }

   Mx::Service->update( list => [ @services ] );

   map { $_->prepare_for_serialization } @services;

   return @services;
}

#------------------#
sub service_action {
#------------------#
    my ( $class, %args ) = @_;


    if ( my $service = Mx::Service->new( name => $args{name}, location => $instance, logger => $sec_logger, config => $config ) ) {
        my $db_audit = Mx::DBaudit->new( logger => $sec_logger, config => $config );
		my $rc;
		if ( $args{action} eq 'start' ) {
            $rc = $service->start( db_audit => $db_audit );
        }
		elsif ( $args{action} eq 'stop' ) {
            $rc = $service->stop( db_audit => $db_audit );
        }
        $db_audit->close;
        return $rc;
    }
}

#------------------------#
sub service_action_async {
#------------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->service_action_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my $result = Mx::Secondary->service_action( %args );

        my $value;
        eval { $value = freeze( [ $result ] ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#--------------#
sub collectors {
#--------------#
   my ( $class, %args ) = @_;


   my @collectors = Mx::Collector->list( location => $instance, logger => $sec_logger, config => $config );

   foreach my $collector ( @collectors ) {
       $collector->check;
       $collectors{ $collector->name } = $collector;
   }

   map { $_->prepare_for_serialization } @collectors;

   return @collectors;
}

#--------------#
sub mcollector {
#--------------#
   my ( $class, %args ) = @_;


   my @collectors = ();

   foreach my $name ( @{$args{names}} ) {
       my $collector = $collectors{$name};
       if ( $collector ) {
           $collector->unprepare_for_serialization( logger => $sec_logger, config => $config );
       }
       else {
           $collector = Mx::Collector->new( name => $name, logger => $sec_logger, config => $config );
           $collectors{$name} = $collector;
       }
       push @collectors, $collector;
   }

   map { $_->check } @collectors;

   map { $_->prepare_for_serialization } @collectors;

   return @collectors;
}

#--------------------#
sub mcollector_async {
#--------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return 0 if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->mcollector_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @collectors = Mx::Secondary->mcollector( %args );

        my $value;
        eval { $value = freeze( \@collectors ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#-------------------#
sub start_collector {
#-------------------#
    my ( $class, $name ) = @_;

    if ( my $collector = Mx::Collector->new( name => $name, logger => $sec_logger, config => $config ) ) {
        return $collector->start( enable => 1 );
    }
}

#------------------#
sub stop_collector {
#------------------#
    my ( $class, $name ) = @_;

    if ( my $collector = Mx::Collector->new( name => $name, logger => $sec_logger, config => $config ) ) {
        return $collector->stop( disable => 1 );
    }
}

#-----------------#
sub env_variables {
#-----------------#
    my ( $class, $pid ) = @_;


    return Mx::Process->env_variables( $pid );
}

#---------------#
sub system_info {
#---------------#
    my ( $class, %args ) = @_;


    my $system = Mx::System->new( config => $config, logger => $sec_logger );
    
    return $system->info;
}

#---------------------#
sub system_info_async {
#---------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->system_info_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my $result = Mx::Secondary->system_info( %args );

        my $value;
        eval { $value = freeze( [ $result ] ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#---------------------#
sub local_filesystems {
#---------------------#
    my ( $class ) = @_;


    my @filesystems = Mx::Filesystem->retrieve_all( type => $Mx::Filesystem::TYPE_LOCAL, config => $config, logger => $sec_logger );

    foreach my $filesystem ( @filesystems ) {
        $filesystem->update;
        $filesystem->prepare_for_serialization;
    }

    return @filesystems;
}

#---------------------------#
sub local_filesystems_async {
#---------------------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->local_filesystems_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @filesystems = Mx::Secondary->local_filesystems( %args );

        my $value;
        eval { $value = freeze( \@filesystems ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#------------#
sub filesync {
#------------#
    my ( $self, %args ) = @_;


    my $filesync = Mx::FileSync->new( target => $args{target}, recursive => $args{recursive}, logger => $sec_logger );

    $filesync->analyze();

    return $filesync;
}

#-------------#
sub read_file {
#-------------#
    my ( $self, %args ) = @_;


    my $fh;
    unless ( $fh = IO::File->new( $args{path}, '<' ) ) {
        $sec_logger->error("unable to open $args{path}: $!"); 
        return;
    }

    my $content = '';
    while ( <$fh> ) {
        $content .= $_;
    }

    $fh->close;

    return $content;
}

#--------------#
sub write_file {
#--------------#
    my ( $self, %args ) = @_;


    my $fh;
    unless ( $fh = IO::File->new( $args{path}, '>' ) ) {
        $sec_logger->error("unable to open $args{path}: $!"); 
        return;
    }

    print $fh $args{content};

    $fh->close;

    unless ( chmod( $args{perms}, $args{path} ) ) {
        $sec_logger->error("unable to set permissions on $args{path}: $!"); 
        return;
    }

    return 1;
}

#---------------#
sub delete_file {
#---------------#
    my ( $self, %args ) = @_;


    unless( unlink( $args{path} ) ) {
        $sec_logger->error("unable to remove $args{path}: $!");
        return;
    }

    return 1;
}

#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return if $self->{disabled};
        return $self->{soaphandle}->run( %args )->paramsall;
    }

    $SIG{'CHLD'} = 'DEFAULT';

    my ( $success, $error_code, $output, $pid ) = Mx::Process->run( command => $args{command}, directory => $args{directory}, timeout => $args{timeout}, config => $config, logger => $sec_logger, mxweblog => $args{mxweblog} );

    return ( $success, $error_code, $output, $pid );
}

#-------------#
sub run_async {
#-------------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return if $self->{disabled};
        return $self->{async_key} = $self->{soaphandle}->run_async( %args )->paramsall;
    }

    my $share_key = _share_key();

    my $pid = fork();

    if ( $pid == 0 ) {
        my $share;
        eval { $share = IPC::ShareLite->new( -key => $share_key, -create => 1, -exclusive => 1, -destroy => 0 ); };

        if ( $@ ) {
            $sec_logger->logdie("cannot create a shared memory segment (key: $share_key): $@");
        }

        _register_share( key => $share_key );

        $share->lock( LOCK_EX );

        my @result = Mx::Secondary->run( %args );

        my $value;
        eval { $value = freeze( \@result ) };

        if ( $@ ) {
            $share->unlock;
            $sec_logger->logdie($@);
        }

        $share->store( $value );

        $share->unlock;

        exit 0;
    }

    return $share_key;
}

#--------#
sub stop {
#--------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return () if $self->{disabled};
        return $self->{soaphandle}->stop( %args )->paramsall;
    }

    my ( $success, $error_code, $output, $pid ) = Mx::Process->run( command => 'secondary_monitor.pl -stop', config => $config, logger => $sec_logger );

    return ( $success, $error_code, $output, $pid );
}

#-----------#
sub restart {
#-----------#
    my ( $self, %args ) = @_;


    if ( ref($self) eq 'Mx::Secondary' ) {
        return () if $self->{disabled};
        return $self->{soaphandle}->restart( %args )->paramsall;
    }

    my ( $success, $error_code, $output, $pid ) = Mx::Process->run( command => 'secondary_monitor.pl -restart', config => $config, logger => $sec_logger );

    return ( $success, $error_code, $output, $pid );
}

#------------#
sub avg_load {
#------------#
    my ( $class ) = @_;


    my $ostype = Mx::Process->ostype;

    if ( $ostype eq 'solaris' ) {
        return sprintf("%.2f", (Solaris::loadavg::loadavg(1))[0]);
    }
    elsif ( $ostype eq 'linux' ) {
        open FH, '/proc/loadavg';
        my $line = <FH>;
        CORE::close(FH);
        return ( split ' ', $line )[0];
    }
}

#----------------#
sub avg_scanrate {
#----------------#
    my ( $class, %args ) = @_;
 
 
    my $avg_scanrate_file = $config->AVG_SCANRATE_FILE;
 
    my $fh;
    unless ( $fh = IO::File->new( $avg_scanrate_file, '<' ) ) {
        $sec_logger->error("avg_load: cannot open $avg_scanrate_file: $!");
        return 0;
    }
 
    my $avg_scanrate = <$fh>;
 
    $fh->close();
 
    return $avg_scanrate;
}

#--------------#
sub _share_key {
#--------------#
    return int(rand(2_000_000_000));
}

1;
