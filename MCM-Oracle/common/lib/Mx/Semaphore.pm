package Mx::Semaphore;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Alert;
use Fcntl ':flock';
use IO::File;
use File::Basename;
use Carp;

our $TYPE_COUNT     = 1;
our $TYPE_TIME      = 2;
our $TYPE_INCREMENT = 3;

#
# properties
#
# key
# type
# count (in case of type $TYPE_COUNT)
# fh    (in case of type $TYPE_TIME) 
# path
#

#-------#
sub new {
#-------#
    my  ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };
 
    #
    # check the arguments
    #
    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex semaphore (config)");
    }

    my $key;
    unless ( $key = $self->{key} = $args{key} ) {
        $logger->logdie("missing argument in initialisation of Murex semaphore (key)");
    }

    my $type = $self->{type} = $args{type} || $TYPE_COUNT;

    unless ( $type == $TYPE_COUNT or $type == $TYPE_TIME or $type == $TYPE_INCREMENT ) {
        $logger->logdie("wrong argument in initialisation of Murex semaphore (type)");
    }

    my $directory = $args{directory} || $config->retrieve('SEMAPHOREDIR');

    my $path = $directory . '/' . $key . '.sem';
    $self->{path} = $path;

    if ( -f $path && ! $args{reset} ) {
        $logger->debug("semaphore '$key' ($path) found");
    }
    elsif ( $args{create} ) {
        my $fh;
        unless ( $fh = IO::File->new( $path, '>' ) ) {
            $logger->error("cannot create new semaphore '$key' ($path: $!)");
            return;
        }

        if ( $type == $TYPE_COUNT ) {
            my $count = $args{count} || 1;

            if ( $count > 999 ) {
                $logger->logdie("maximum allowed semaphore count is 999");
            }
      
            printf $fh "%03d:%03d", $count, $count;

            $self->{initial_count} = $count;
            $self->{count} = 0;
        }
        elsif ( $type == $TYPE_TIME ) {
            print $fh time();

            $self->{fh} = undef;
        }
        elsif ( $type == $TYPE_INCREMENT ) {
            my $count = $args{count} || 0;

            printf $fh "%d", $count;

            $self->{fh}    = undef;
            $self->{count} = 0;
        }

        $fh->close();

        $logger->debug("semaphore '$key' ($path) created");
    }
    else {
        $logger->error("semaphore '$key' ($path) not found");
        return;
    }
   
    bless $self, $class;
}

#-----------#
sub acquire {
#-----------#
    my ( $self, %args ) = @_;


    my $type          = $self->{type};
    my $key           = $self->{key};
    my $path          = $self->{path};
    my $logger        = $self->{logger};
    my $config        = $self->{config};
    my $non_blocking  = $args{non_blocking};
    my $no_fail       = $args{no_fail};
    my $alternate_key = $args{alternate_key};

    if ( $self->{count} or $self->{fh} ) {
        $logger->warn("semaphore '$key' is already acquired");
        return 1;
    }

    my $max_retries   = $args{max_retries} || $config->retrieve('MAX_SEMAPHORE_RETRIES');
    my $poll_interval = $args{poll_interval} || 1;

    my $fh; my $count; my $current_count; my $max_count; my $retries = 0;
    while ( ( $retries < $max_retries ) || ( $max_retries == -1 ) ) {
        unless ( $fh = IO::File->new( $path, '+<' ) ) {
            $logger->logdie("cannot find semaphore file $path");
        }

        flock $fh, LOCK_EX;

        if ( $type == $TYPE_COUNT ) {
            $count = $args{count} || 1;

            my $entry = <$fh>;

            if ( $entry =~ /^(\d+):(\d+)$/ ) {
                $max_count     = $1;
                $current_count = $2;
            }
            else {
                $current_count = $entry;
            }

            $current_count += 0;

            if ( $current_count >= $count ) {
                last;
            }

            $logger->warn("current set for semaphore '$key' is $current_count, cannot accommodate a request for $count") unless $args{quiet};

            $fh->close;

            return -1 if $non_blocking;

            $retries++;

            sleep $poll_interval;
        }
        elsif ( $type == $TYPE_TIME ) {
            $self->{timestamp} = <$fh>;

            last;
        }
        elsif ( $type == $TYPE_INCREMENT ) {
            $self->{count} = <$fh>;

            $self->{count}++;
        }
    }

    if ( $retries == $max_retries ) {
        my $alert = Mx::Alert->new( name => 'semaphore_lock', config => $config, logger => $logger );
        $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $retries * $poll_interval ], item => $key );
        if ( $no_fail ) {
            $logger->warn("maximum number of semaphore retries reached (maybe remove $path)?");
            return;
        }
        else {
            $logger->logdie("maximum number of semaphore retries reached (maybe remove $path)?");
        }
    }

    my $rc = 0;
    if ( $type == $TYPE_COUNT ) {
        my $new_count = $current_count - $count;

        seek $fh, 0, 0;

        if ( $max_count ) {
            printf $fh "%03d:%03d", $max_count, $new_count;
        }
        else {
            printf $fh "%03d", $new_count;
        }

        $fh->close;

        $self->{count} = $count;

        $logger->debug("semaphore '$key' acquired (acquired $count, $new_count remaining)");

        $rc = $new_count;
    }
    elsif ( $type == $TYPE_TIME or $type == $TYPE_INCREMENT ) {
        $self->{fh} = $fh;

        $logger->debug("semaphore '$key' acquired");

        $rc = 1;
    }

    if ( $alternate_key ) {
        my $alternate_path = dirname( $path ) . '/' . $alternate_key . '.sem';

        unless ( link $path, $alternate_path ) {
            $logger->logdie("cannot hardlink $alternate_path to $path");
        }

        $logger->debug("alternate key '$alternate_key' linked to semaphore '$key'");
    }

    return $rc;
}

#-----------#
sub release {
#-----------#
    my ( $self, %args ) = @_;


    my $key           = $self->{key};
    my $type          = $self->{type};
    my $path          = $self->{path};
    my $logger        = $self->{logger};
    my $delay         = $args{delay};
    my $max_own_delay = $args{max_own_delay};
    my $cleanup       = $args{cleanup};

    unless ( $self->{count} or $self->{fh} ) {
        $logger->warn("semaphore '$key' is already released or never acquired");
        return 1;
    } 

    if ( $type == $TYPE_COUNT ) {
        my $count = $self->{count};

        my $fh;
        unless ( $fh = IO::File->new( $path, '+<' ) ) {
            $logger->error("cannot find semaphore file $path");
            return;
        }

        flock $fh, LOCK_EX;

        my $current_count; my $max_count;

        my $entry = <$fh>;

        if ( $entry =~ /^(\d+):(\d+)$/ ) {
            $max_count     = $1;
            $current_count = $2;
        }
        else {
            $current_count = $entry;
        }

        my $new_count = $current_count + $count;

        seek $fh, 0, 0;

        if ( $max_count ) {
            $new_count = ( $new_count > $max_count ) ? $max_count : $new_count;
            printf $fh "%03d:%03d", $max_count, $new_count;
        }
        else {
            printf $fh "%03d", $new_count;
        }

        $fh->close;

        $self->{count} = 0;

        $logger->debug("semaphore '$key' released (released $count, $new_count remaining)");
    }
    elsif ( $type == $TYPE_TIME ) {
        unless ( $delay ) {
            $logger->logdie("no delay specified for timebased semaphore");
        } 

        my $timestamp = $self->{timestamp};

        my $sleeptime = $timestamp - time();

        if ( $max_own_delay and $sleeptime > $max_own_delay ) {
            $sleeptime = $max_own_delay;
        }

        if ( $sleeptime > 0 ) {
            $timestamp += $delay;
        }
        else {
            $timestamp = time() + $delay;
        }

        my $fh = $self->{fh};

        seek $fh, 0, 0;

        print $fh $timestamp;

        $fh->close;

        $self->{fh} = undef;

        $logger->debug("semaphore '$key' released (delay of $delay seconds, new timestamp $timestamp)");

        if ( $sleeptime > 0 ) { 
            $logger->debug("going to sleep for $sleeptime seconds");

            sleep $sleeptime;
        }
    }
    elsif ( $type == $TYPE_INCREMENT ) {
        my $fh    = $self->{fh};
        my $count = $self->{count};

        seek $fh, 0, 0;

        print $fh $count;

        $fh->close;

        $self->{fh} = undef;

        $logger->debug("semaphore '$key' released (new count $count)");
    }

    if ( $cleanup ) {
        if ( unlink $path ) {
            $logger->debug("semaphore '$key' cleaned up");
        }
        else {
            $logger->error("unable to cleanup semaphore '$key': $!");
        }
    }

    return 1;
}

#--------------------#
sub external_release {
#--------------------#
    my ( $self, %args ) = @_;


    my $key    = $self->{key};
    my $type   = $self->{type};
    my $logger = $self->{logger};

    unless ( $type == $TYPE_COUNT) {
        $logger->logdie("semaphore '$key' is not of type count, so cannot be externally released");
    }

    $self->{count} = $args{count} || 1;

    $self->release( %args );
}

#-----------------#
sub current_value {
#-----------------#
    my ( $self, %args ) = @_;


    my $type   = $self->{type};
    my $path   = $self->{path};
    my $logger = $self->{logger};

    my $fh;
    unless ( $fh = IO::File->new( $path, '<' ) ) {
        $logger->error("cannot find semaphore file $path");
        return;
    }

    my $entry = <$fh>;

    $fh->close();

    return ( $type == $TYPE_COUNT ) ? ( split /:/, $entry )[1] : $entry;
}

#-----------------#
sub initial_value {
#-----------------#
    my ( $self ) = @_;


    return $self->{initial_count};
}
     
#-------------#
sub increment {
#-------------#
    my ( $self, %args ) = @_;


    $self->acquire;
    $self->release;

    my $count = $self->{count};
    $self->{count} = 0;

    return $count;
}

1;
