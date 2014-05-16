package Mx::Secondary::QueueItem;

use strict;
use warnings;

use Carp;

#
# Attributes:
#
# $name
# $instance
# $method
# %method_args
# %dependencies
# $order
# $poll_interval;
# $timeout
# pre_handler
# post_handler
# fail_handler
# $status
# $timestamp_last_poll
# $timestamp_added
# $timestamp_started
# $timestamp_finished
# $async_key 
# @returnvalues
#

our $STATUS_WAITING        = 'waiting';
our $STATUS_READY          = 'ready';
our $STATUS_RUNNING        = 'running';
our $STATUS_FINISHED       = 'finished';
our $STATUS_FAILED         = 'failed';

our $DEFAULT_POLL_INTERVAL = 5;

my %METHODS = (
  run            => 'run_async',
  service_action => 'service_action_async'
);

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my @required_args = qw(name instance handle method method_args order);
    foreach my $arg (@required_args) {
        unless ( exists $args{$arg} ) {
            $logger->logdie("missing argument in initialisation of queue item ($arg)");
        }
        $self->{$arg} = $args{$arg};
    }

	my $name = $self->{name};

    my $method = $self->{method};
    unless ( $self->{method} = $METHODS{$method} ) {
        $logger->logdie("invalid method ($method) for item $name");
    }

    $self->{dependencies} = {};
    if ( $args{dependencies} ) {
        if ( ref( $args{dependencies} ) eq 'ARRAY' ) {
            map { $self->{dependencies}->{$_} = 0 } @{$args{dependencies}};
        }
        else {
            $self->{dependencies}->{ $args{dependencies} } = 0;
        }

        $self->{status} = $STATUS_WAITING;
		my $dependencies = join ',', keys %{$self->{dependencies}};
		$logger->debug("item $name added, dependencies: $dependencies");
    }
	else {
        $self->{status} = $STATUS_READY;
		$logger->debug("item $name added, no dependencies");
    }

	$self->{poll_interval} = $args{poll_interval} || $DEFAULT_POLL_INTERVAL;
	$self->{timeout}       = $args{timeout} || 0;

	$self->{pre_handler}  = $args{pre_handler}  || sub {};
	$self->{post_handler} = $args{post_handler} || sub {};
	$self->{fail_handler} = $args{fail_handler} || sub {};

    $self->{timestamp_added} = time();

    bless $self, $class;
}

#----------------------#
sub check_dependencies {
#----------------------#
    my ( $self, @dependencies ) = @_;


	return 1 if $self->{status} eq $STATUS_READY;

    return 0 if $self->{status} ne $STATUS_WAITING;

	my $name = $self->{name};

	foreach my $dependency ( @dependencies ) { 
        if  ( exists $self->{dependencies}->{$dependency} ) {
            $self->{dependencies}->{$dependency} = 1;
        }
    }

    foreach my $value ( values %{$self->{dependencies}} ) {
        return 0 unless $value;
    }

	$self->{logger}->debug("checking dependencies for item $name (@dependencies)");
	$self->{logger}->debug("item $name is ready to run");

	$self->{status} = $STATUS_READY;

    return 1;
}

#-------#
sub run {
#-------#
    my ( $self ) = @_;


	return unless $self->{status} eq $STATUS_READY;

	my $handle      = $self->{handle};
	my $method      = $self->{method};
	my $name        = $self->{name};
	my $method_args = $self->{method_args};

	$self->{logger}->debug("running item $name");

	&{$self->{pre_handler}}($self);

    $self->{timestamp_started}   = time();
	$self->{timestamp_last_poll} = time();

	$self->{async_key} = $handle->$method( %{$method_args} );

	$self->{logger}->debug("item $name is running");

	$self->{status} = $STATUS_RUNNING;
}

#--------#
sub poll {
#--------#
    my ( $self ) = @_;


	return unless $self->{status} eq $STATUS_RUNNING;

	return if ( time() - $self->{timestamp_last_poll} ) < $self->{poll_interval};

	$self->{timestamp_last_poll} = time();

	my $name = $self->{name};

    if ( my @returnvalues = $self->{handle}->poll_async( key => $self->{async_key}, no_block => 1 ) ) {
        $self->{timestamp_finished} = time();
        $self->{returnvalues}       = \@returnvalues;

	    if ( $returnvalues[0] ) {
	        $self->{logger}->debug("item $name has finished");
            $self->{status} = $STATUS_FINISHED;
		    &{$self->{post_handler}}($self);
        }
		else {
	        $self->{logger}->error("item $name has failed");
            $self->{status} = $STATUS_FAILED;
            &{$self->{fail_handler}}($self);
        }

	    return 1;
    }

	if ( $self->{timeout} ) {
	    my $runtime = time() - $self->{timestamp_started};

		if ( $runtime > $self->{timeout} ) {
            $self->{timestamp_finished} = time();
            $self->{returnvalues}       = [];
            $self->{status}             = $STATUS_FAILED;

	        $self->{logger}->error("item $name has timed out");

	        &{$self->{fail_handler}}($self);

	        return 1;
        } 
    }

	return 0;
}

#----------------#
sub returnvalues {
#----------------#
    my ( $self ) = @_;


	return @{$self->{returnvalues}};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;


	return $self->{status};
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


	return $self->{name};
}

#------------#
sub instance {
#------------#
    my ( $self ) = @_;


	return $self->{instance};
}

1;
