package Mx::Secondary::Queue;

use strict;
use warnings;

use Carp;
use Mx::Secondary::QueueItem;

#
# Attributes:
#
# %handles
# %names
# @items
# $threshold
# $timestamp_started
# $timestamp_finished
# $timeout
#

my $DEFAULT_POLL_INTERVAL = 5;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = { logger => $logger };

    $self->{handles} = {};
    $self->{items}   = [];
	$self->{names}   = {};
   
    $self->{threshold}     = $args{threshold}     || 0;
	$self->{poll_interval} = $args{poll_interval} || $DEFAULT_POLL_INTERVAL;
	$self->{timeout}       = $args{timeout}       || 0; 
	$self->{nr_added}      = 0;
	$self->{nr_ready}      = 0;
    $self->{nr_running}    = 0;
	$self->{nr_finished}   = 0;
	$self->{nr_failed}     = 0;


    bless $self, $class;
}

#--------------#
sub add_handle {
#--------------#
    my ( $self, %args ) = @_;


    my $handle    = $args{handle};
    my $threshold = $args{threshold} || 0;
    my $instance  = $handle->instance;

    $self->{handles}->{$instance} = { handle => $handle, threshold => $threshold, nr_running => 0 };

	return 1;
}

#------------#
sub add_item {
#------------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $instance = $args{instance};
	my $name     = $args{name};

	if ( exists $self->{names}->{$name} ) {
        $logger->error("an item with as name $name has already been added");
		return;
    }

    unless ( exists $self->{handles}->{$instance} ) {
        $logger->error("cannot add item $name because a handle for instance $instance does not exist");
		return; 
    }

    my $handle = $self->{handles}->{$instance}->{handle};

    if ( my $item = Mx::Secondary::QueueItem->new( %args, order => $self->{nr_added} + 1, handle => $handle, logger => $logger ) ) {
		$self->{nr_added}++;
	    push @{$self->{items}}, $item;
	    $self->{names}->{$name} = $item;
		return 1;
    }

	$logger->error("item $name cannot be added");

	return;
}

#----------------------#
sub check_dependencies {
#----------------------#
    my ( $self, @finished_items ) = @_;


	my @dependencies = map { $_->name } @finished_items;

	$self->{nr_ready} = 0;
	map { $self->{nr_ready} += $_->check_dependencies( @dependencies ) } @{$self->{items}};

	return $self->{nr_ready};
}

#-------#
sub run {
#-------#
    my ( $self ) = @_;


	my $logger = $self->{logger};

	my $remaining = $self->{nr_added} - $self->{nr_finished} - $self->{nr_failed};

    $logger->debug("running queue with $remaining items");

	$self->{timestamp_started} = time();

	my $runtime;
	while ( $remaining > 0 ) {
		my @finished_items = ();

		foreach my $item ( @{$self->{items}} ) {
			my $status  = $item->status;

			next if $status eq $Mx::Secondary::QueueItem::STATUS_FINISHED;
			next if $status eq $Mx::Secondary::QueueItem::STATUS_WAITING;
			next if $status eq $Mx::Secondary::QueueItem::STATUS_FAILED;

			my $handle_ref = $self->{handles}->{ $item->instance };

			if ( $status eq $Mx::Secondary::QueueItem::STATUS_READY ) {
				next if ( $self->{nr_running} >= $self->{threshold} && $self->{threshold} != 0 );
				next if ( $handle_ref->{nr_running} >= $handle_ref->{threshold} && $handle_ref->{threshold} != 0 );

				$item->run();

				$self->{nr_running}++;
				$self->{nr_ready}--;
				$handle_ref->{nr_running}++;

				$logger->debug("queue has $self->{nr_running} running items");
            }
			elsif ( $status eq $Mx::Secondary::QueueItem::STATUS_RUNNING ) {
				next unless $item->poll;

			    $self->{nr_running}--;
			    $handle_ref->{nr_running}--;

				if ( $item->status eq $Mx::Secondary::QueueItem::STATUS_FINISHED ) {
			        $self->{nr_finished}++;
				    push @finished_items, $item;
                }
				elsif ( $item->status eq $Mx::Secondary::QueueItem::STATUS_FAILED ) {
			        $self->{nr_failed}++;
                }

	            $remaining = $self->{nr_added} - $self->{nr_finished} - $self->{nr_failed};

				$logger->debug("queue has $remaining remaining items");
            }
        }

		$self->check_dependencies( @finished_items ) if @finished_items;

		next if $self->{nr_ready};

		if ( $remaining > 0 && $self->{nr_running} == 0 ) {
			$logger->error("aborting queue, dependencies unresolvable");
			return 0; 
        }

	    $runtime = time() - $self->{timestamp_started};

		if ( $self->{timeout} && $runtime > $self->{timeout} ) {
			$logger->error("timeout reached ($self->{timeout}), aborting queue");
			return 0;
        }

		sleep 1;
    }

	$self->{timestamp_finished} = time();

	$runtime = $self->{timestamp_finished} - $self->{timestamp_started};

	$logger->debug("queue runtime was $runtime seconds");
	$logger->debug("# of items finished: $self->{nr_finished}");
	$logger->debug("# of items failed: $self->{nr_failed}");

	return ( $self->{nr_failed} ) ? 0 : 1;
}

1;
