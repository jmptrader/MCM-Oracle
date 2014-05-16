package MLC::Service;

# Fields
#
# name:              name of the service, for example 'limits_server'
# launcher:          full path to launchmlc.sh
# options:           options needed to start the service via launchmlc.sh, for example '-jls'
# params:            optional additional parameters
# descriptor:        unique string which is used to identify the process
# order:             relative order in which the services should be started
# post_start_action: action which must be performed after the service is started
# pre_stop_action:   action which must be performed before the service is stopped
# status:            state of the service (STARTING, STARTED,...) (there might be more than one process per service - namely one per descriptor)
# process:           corresponding Mx::Process object
#

use strict;
use warnings;

use Carp;
use Cwd;
use File::Basename;
use IO::File;
use Mx::Config;
use Mx::Process;
use Data::Dumper;

use constant LAUNCHER      => 'launchmlc.sh';

use constant START_DELAY   => 5;
use constant STOP_DELAY    => 5;

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

    my $logger = $args{logger} or croak 'no logger defined';
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex service (name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex service (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    $self->{config} = $config;

    my $service_ref;
    unless ( $service_ref = $config->retrieve("%SERVICES%$name") ) {
        $logger->logdie("service '$name' is not defined in the configuration file");
    }

    foreach my $param (qw(options descriptor params order post_start_action post_start_desc pre_stop_action pre_stop_desc logfile pidfile)) {
        unless ( exists $service_ref->{$param} ) {
            $logger->logdie("parameter '$param' for service '$name' is not defined in the configuration file");
        }
        $self->{$param} = $service_ref->{$param};
    }

    #
    # determine the full path to the 'launcher'
    #
    $self->{launcher} = $config->MXENV_ROOT . '/bin/' . LAUNCHER;
    unless ( -f $self->{launcher} ) {
        $logger->error('cannot find launcher ', $self->{launcher});
    }

    my @disabled_services = ();
    my $ref = $config->retrieve( 'DISABLE_SERVICE', 1 );
    if ( $ref ) {
      if ( ref($ref) eq 'ARRAY' ) {
          @disabled_services = @{$ref};
      }
      else {
          @disabled_services = ( $ref );
      }
    }

    if ( grep /^$name$/, @disabled_services ) {
        $self->{status} = DISABLED;
    }
    else {
        $self->{status} = UNKNOWN;
    }

    $self->{process}     = undef;
    $self->{performance} = $args{performance};

    $logger->debug("service '$name' initialized");

    bless $self, $class;
}

#
# Returns a ordered list of all MLC::Service objects that can be found in the configuration file
# 
# Arguments:
#   config: a Mx::Config instance
#   logger: a Mx::Log instance
#
#--------#
sub list {
#--------#
    my ($class, %args) = @_;


    my @services = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }

    $logger->debug('scanning the configuration file for services');

    my $services_ref;
    unless ( $services_ref = $config->SERVICES ) {
        $logger->logdie("cannot access the services section in the configuration file");
    }

    foreach my $name (keys %{$services_ref}) {
        my $service = MLC::Service->new( name => $name, config => $config, logger => $logger, performance => $args{performance} );
        $logger->debug("service '$name' found");
        push @services, $service;
    }

    my $nr_services = @services;
    $logger->debug("found $nr_services services in the configuration file");

    #
    # already order the services
    #
    @services = sort { $a->{order} <=> $b->{order} } @services;

    return @services;
}

#
# This class method takes as argument a list of MLC::Service objects and updates the status and process fields.
# One prerequisite: all services should belong to the same environment.
#
#----------#
sub update {
#----------#
    my ($class, @list) = @_;


    unless ( @list ) {
        croak 'no arguments';
    }

    #
    # 'borrow' the logger, config, and launcher from the first object in the list
    #
    my $service = $list[0];
    unless ( ref($service) eq 'MLC::Service' ) {
        croak 'only MLC::Service objects are allowed as arguments';
    }
    my $logger      = $service->{logger};
    my $config      = $service->{config};
    my $performance = $service->{performance};

    #
    # for every service, lookup the corresponding process
    #
    foreach $service (@list) {
        unless ( ref($service) eq 'MLC::Service' ) {
            $logger->logdie('only MLC::Service objects are allowed as arguments');
        }

        my $name          = $service->{name};
        my $descriptor    = $service->{descriptor};
        my $pidfile       = $service->{pidfile};

        if ( $service->{status} == DISABLED ) {
            $logger->debug("service '$name' is disabled");
        }
        elsif ( my $process = Mx::Process->new( pidfile => $pidfile, config => $config, logger => $logger, performance => $performance, exclude_anon => 1 ) ) {
            if ( $process->cmdline =~ /$descriptor/ ) {
                $process->descriptor( $descriptor ); 
                $service->{process} = $process;
                $service->{status}  = STARTED;
                $logger->debug("service '$name' is running");
            }
            else {
                $service->{process} = undef;
                $service->{status}  = STOPPED;
                $logger->debug("service '$name' is not running");
            }
        }
        else {
            $service->{process} = undef;
            $service->{status}  = STOPPED;
            $logger->debug("service '$name' is not running");
        }
    }
}


#---------#
sub start {
#---------#
    my ($self, $apache_request) = @_;

   
    my $logger = $self->{logger};
    my $config = $self->{config};
    my $name   = $self->{name};

    $logger->debug("starting service '$name'");

    if ( $self->{status} == UNKNOWN ) {
        MLC::Service->update($self);
    }

    unless ( $self->{status} == STOPPED ) {
        $logger->warn("trying to start a service ($name) which is not stopped");
        return 1;
    }

    my $logfile    = $self->{logfile};
    my $pidfile    = $self->{pidfile};
    my $descriptor = $self->{descriptor};

    if ( $apache_request ) {
        my $command = $self->{launcher} . ' ' . $self->{options} . ' ' . $self->{params} . " >>$logfile 2>&1";

        Mx::Process->run( command => $command, logger => $logger, config => $config, directory => dirname($self->{launcher}), apache_request => $apache_request, pidfile => $pidfile, logfile => $logfile );

        sleep START_DELAY;
    }
    else {
        my $command = $self->{launcher} . ' ' . $self->{options} . ' ' . $self->{params};

        my $process;
        unless ( $process = Mx::Process->background_run( command => $command, logger => $logger, config => $config, directory => dirname($self->{launcher}), output => $logfile, ignore_child => 1 ) ) {
            $logger->error("starting of service '$name' failed");
            return 0;
        }

        sleep START_DELAY;

        $process->set_pidfile( $descriptor, $pidfile );
    }

    MLC::Service->update($self);

    if ( $self->{status} == STARTED ) {
        $logger->info("service '$name' is successfully started");
    }
    else {
        $logger->error("starting of service '$name' failed");
        return 0;
    }

    if ( my $action = $self->{post_start_action} ) {
        $logger->info("executing post-start action: $action");

        my $rc = system($action);

#        if ( $rc == 0 ) {
#            $logger->info("post-start action completed successfully");
#            return 1;
#        }
#        else {
#            $logger->error("post-start action failed with returncode $rc");
#            return 0;
#        }
    }

    return 1;
}

#--------#
sub stop {
#--------#
    my ($self) = @_;


    my $logger = $self->{logger};
    my $name   = $self->{name};

    $logger->debug("stopping service '$name'");

    if ( $self->{status} == UNKNOWN ) {
        MLC::Service->update($self);
    }

    unless ( $self->{status} == STARTED or $self->{status} == FAILED ) {
        $logger->warn("trying to stop a service ($name) which is not running");
        return;
    }

    chdir( dirname($self->{launcher}) );

    if ( my $action = $self->{pre_stop_action} ) {
        $logger->info("executing pre-stop action: $action");

        my $rc = system($action);

        if ( $rc == 0 ) {
            $logger->info("pre-stop action completed successfully");
        }
        else {
            $logger->error("pre-stop action failed with returncode $rc");
        }
    }

    my $process = $self->process;

    $process->kill;

    sleep STOP_DELAY;

    MLC::Service->update($self);

    if ( $self->{status} == STOPPED ) {
        $logger->info("service '$name' is successfully stopped");
        return 1;
    }
    else {
        $logger->error("stopping of service '$name' failed");
        return 0;
    }
}

#--------#
sub name {
#--------#
    my ($self) = @_;

    return $self->{name};
}

#----------#
sub status {
#----------#
    my ($self) = @_;

    return $STATUS{$self->{status}};
}

#---------#
sub order {
#---------#
    my ($self) = @_;

    return $self->{order};
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

#--------------#
sub descriptor {
#--------------#
    my ($self) = @_;

    return $self->{descriptor};
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

#-----------#
sub pidfile {
#-----------#
    my ($self) = @_;

    return $self->{pidfile};
}

#-----------#
sub logfile {
#-----------#
    my ($self) = @_;

    return $self->{logfile};
}

#-----------#
sub process {
#-----------#
    my ($self) = @_;

    return $self->{process};
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

