package Mx::IPC::SHM;

use Carp;
use Mx::Config;
use Mx::Log;

#
# Attributes:
#
# id
# owner
# nr_attachments
# creator_pid
# config
# logger
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;
 
 
    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };
 
    #
    # check the arguments
    #
    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of IPC::SHM (config)");
    }

    foreach my $param (qw( id owner nr_attachments creator_pid )) {
        unless ( exists $args{$param} ) {
            $logger->logdie("missing argument in initialisation of IPC::SHM ($param)");
        }
        $self->{$param} = $args{$param};
    }
 
    bless $self, $class;
}

#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @shms = ();
 
    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
 
    $logger->debug('retrieving all shared memory segments');

    unless ( open CMD, '/usr/bin/ipcs -pom|' ) {
        $logger->logdie("cannot retrieve list of shared memory segments: $!");
    }

    while ( my $line = <CMD> ) {
        my ( $id, $owner, $nr_attachments, $creator_pid );
        if ( $line =~ /^m\s+(\d+)\s+\S+\s+\S+\s+(\w+)\s+\w+\s+(\d+)\s+(\d+)\s+/ ) {
            $id             = $1;
            $owner          = $2;
            $nr_attachments = $3;
            $creator_pid    = $4;
        }

        if ( $args{owner} ) {
            next unless $args{owner} eq $owner;
        }

        if ( exists $args{nr_attachments} ) {
            next unless $nr_attachments == $args{nr_attachments};
        }

        $logger->debug("found shared memory segment: id: $id, owner: $owner, nr_attachments: $nr_attachments, creator_pid: $creator_pid");

        push @shms, Mx::IPC::SHM->new( id => $id, owner => $owner, nr_attachments => $nr_attachments, creator_pid => $creator_pid, logger => $logger, config => $config );
    }

    close(CMD);

    my $nr_shms = @shms;

    $logger->info("found $nr_shms shared memory segments");

    return @shms;
}

#-----------#
sub cleanup {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $id     = $self->{id};

    if ( system("/usr/bin/ipcrm -m $id") ) {
        $logger->error("cannot remove shared memory segment with id $id: $!");
        return;
    }

    $logger->info("shared memory segment with id $id removed");
    return 1;
}

1;
