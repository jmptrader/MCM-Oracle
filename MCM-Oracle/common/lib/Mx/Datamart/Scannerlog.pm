package Mx::Datamart::Scannerlog;

use strict;
use warnings;

use IO::File;
use Carp;


#
# properties:
#
# $parent
# $path
# $size
# $fh
# %scanners
#
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
        $logger->logdie("missing argument in initialisation of scannerfile (config)");
    }

    my $db_audit;
    unless ( $db_audit = $self->{db_audit} = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of scannerfile (db_audit)");
    }

    my $parent;
    unless ( $parent = $self->{parent} = $args{parent} ) {
        $logger->logdie("missing argument in initialisation of scannerfile (parent)");
    }

    unless ( $parent->mx_scanner or $parent->mx_scannernick ) {
        return;
    }

    my $mx_nick        = $parent->mx_nick;
    my $mx_scannernick = $parent->mx_scannernick || 'MXDEALSCANNER.ENGINE';
    my $pid            = $parent->pid;
    my $session_id     = $parent->mx_sessionid;

    my $result = $db_audit->retrieve_session( id => $session_id );

    $self->{mx_scripttype}   = $result->[7];
    $self->{mx_scriptname}   = $result->[8];
    $self->{sched_jobstream} = $result->[20];
    $self->{entity}          = $result->[21];
    $self->{runtype}         = $result->[22];
    $self->{project}         = $result->[26];
    
    my $stats_path = $config->retrieve("%SESSIONS%$mx_nick%stats_path");

    my $path = $stats_path . '/scanner_client.' . $pid . '.log';

    $logger->debug("location of scanner log: $path");

    $self->{parent_id}      = $session_id;
    $self->{path}           = $path;
    $self->{size}           = 0;
    $self->{fh}             = undef;
    $self->{scanners}       = {};
    $self->{mx_scannernick} = $mx_scannernick;
    $self->{feedername}     = '';

    bless $self, $class;
}


#---------#
sub check {
#---------#
    my ( $self ) = @_;


    my $logger    = $self->{logger};
    my $db_audit  = $self->{db_audit};
    my $path      = $self->{path};
    my $fh        = $self->{fh};
    my $scanners  = $self->{scanners};
    my $parent_id = $self->{parent_id};

    if ( $self->{size} == 0 ) {
        return unless -f $path;

        unless ( $fh = $self->{fh} = IO::File->new( $path, '<' ) ) {
            $logger->error("unable to open $path: $!");
            return;
        }

        $logger->debug("scanner log ($path) detected");
    }

    while ( my $line = <$fh> ) {
        if ( $line =~ /Datamart batch of feeder (.+) initialization started/ ) {
            $self->{feedername} = $1;
        }
        elsif ( $line =~ /{ NPID:(\d+) , SID:\d+ , Hostname:\((\w+)\) }$/ ) {
            my $pid      = $1;
            my $hostname = $2;

            my $scanner_id = $db_audit->record_scanner_start( 
              pid             => $pid,
              hostname        => $hostname,
              mx_nick         => $self->{mx_scannernick},
              parent_id       => $parent_id,
              mx_scripttype   => 'scanner',
              mx_scriptname   => $self->{mx_scriptname} || $self->{feedername},
              sched_jobstream => $self->{sched_jobstream},
              entity          => $self->{entity},
              runtype         => $self->{runtype},
              project         => $self->{project}
            );

            $scanners->{"$hostname:$pid"} = $scanner_id if $scanner_id;
        }
        elsif ( $line =~ /{ NPID:(\d+) , SID:\d+ , Hostname:\((\w+)\) } : Elapsed: (\d+\.\d+)\(s\) , CPU: (\d+\.\d+)\(s\), RDB:(\d+\.\d+)\(s\)/ ) {
            my $pid      = $1;
            my $hostname = $2;
            my $runtime  = $3;
            my $cputime  = $4;
            my $iotime   = $5;

            $runtime = int( $runtime + 0.5 );
            $cputime = int( $cputime + 0.5 );
            $iotime  = int( $iotime + 0.5 );

            if ( my $scanner_id = $scanners->{"$hostname:$pid"} ) {
                $db_audit->record_scanner_end( session_id => $scanner_id, runtime => $runtime, cputime => $cputime, iotime => $iotime );
            }
        }
    }

    $self->{size} = -s $path;
}


#----------#
sub finish {
#----------#
    my ( $self ) = @_;
}

1;
