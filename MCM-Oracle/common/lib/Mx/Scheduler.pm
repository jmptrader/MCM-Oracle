package Mx::Scheduler;
 
use strict;
 
use Carp;
use Mx::Log;
use Mx::Config;
use Mx::Util;


my %ENTITIES = (
 LCH => 'LCH',
);

my %REVERSE_ENTITIES = (
 LCH => 'LCH',
);

my %RUNTYPES = (
 O => 'O',
);

my %PILLARS = (
 O => 'O',
 A => 'A',
 P => 'P',
);


# 
# Args:
#
# jobstream: name of the jobstream
# logger:    a logger object
# config:    a config object
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument in initialisation of scheduler (config)');
    }
    $self->{config} = $config;

    #
    # check jobstream argument
    #
    my $jobstream;
    unless ( $jobstream = $args{jobstream} ) {
        $logger->logdie('missing argument in initialisation of scheduler (jobstream)');
    }
    $self->{jobstream} = $jobstream;

    return unless _decode_jobstream( $self );

    my $pipe_directory = $config->retrieve('PIPEDIR') . '/' . $jobstream;

    $self->{pipe_directory} = $pipe_directory;

    unless ( -d $pipe_directory ) {
        unless( mkdir( $pipe_directory ) ) {
            unless ( -d $pipe_directory ) { # might be created in the meantime by a parallel job
                $logger->logdie("cannot create directory $pipe_directory: $!");
            }
        }
    }

    bless $self, $class;
}

#---------------#
sub is_disabled {
#---------------#
    my ( $self ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $jobstream = $self->{jobstream};

    my $sched_configfile = $config->retrieve('SCHED_CONFIGFILE');
    my $sched_config     = Mx::Config->new( $sched_configfile );

    my $enabled_jobstream = $sched_config->retrieve('SCHEDULER.ENABLE_JOBSTREAM', 1);

    my @enabled_jobstreams = ();
    if ( $enabled_jobstream ) {
        if( ref( $enabled_jobstream ) eq 'ARRAY' ) {
            @enabled_jobstreams = @{$enabled_jobstream};
        } 
        else {
            @enabled_jobstreams = ( $enabled_jobstream );
        }
    }

    foreach my $entry ( @enabled_jobstreams ) {
        if ( $jobstream =~ /^$entry$/ ) {
            $logger->info("jobstream $jobstream is enabled");
            return 0;
        }
    }

    my $disabled_jobstream = $sched_config->retrieve('SCHEDULER.DISABLE_JOBSTREAM', 1);

    my @disabled_jobstreams = ();
    if ( $disabled_jobstream ) {
        if( ref( $disabled_jobstream ) eq 'ARRAY' ) {
            @disabled_jobstreams = @{$disabled_jobstream};
        } 
        else {
            @disabled_jobstreams = ( $disabled_jobstream );
        }
    }

    foreach my $entry ( @disabled_jobstreams ) {
        if ( $jobstream =~ /^$entry$/ ) {
            $logger->info("jobstream $jobstream is disabled");
            return 1;
        }
    }

    return 0;
}

#----------------#
sub _pillar_code {
#----------------#
    my ( $jobstream ) = @_;


    return substr( $jobstream, 0, 1 );
}


#----------------#
sub _entity_code {
#----------------#
    my ( $jobstream, $new_entity_code ) = @_;


    if ( $new_entity_code ) {
        substr( $jobstream, 5, 2 ) = $new_entity_code;
        return $jobstream;
    }

    return substr( $jobstream, 5, 2 );
}


#-----------------#
sub _runtype_code {
#-----------------#
    my ( $jobstream ) = @_;


    return substr( $jobstream, 7, 1 );
}

#-------------#
sub jobstream {
#-------------#
    my ( $self ) = @_;


    return $self->{jobstream};
}

#----------#
sub pillar {
#----------#
    my ( $self, $jobstream ) = @_;


    if ( ref($self) eq 'Mx::Scheduler' ) {
        return $self->{pillar};
    }
    else {
        my $pillar_code = _pillar_code( $jobstream );
        return $PILLARS{$pillar_code};
    }
}


#----------#
sub entity {
#----------#
    my ( $self, $jobstream ) = @_;


    if ( ref($self) eq 'Mx::Scheduler' ) {
        return $self->{entity};
    }
    else {
        my $entity_code = _entity_code( $jobstream );
        return $ENTITIES{$entity_code};
    }
}

#--------------#
sub set_entity {
#--------------#
    my ( $self, $entity_code ) = @_;


    my $logger = $self->{logger};

    my $entity;
    unless ( $entity = $ENTITIES{$entity_code} ) {
        $logger->logdie("set_entity: invalid entity specified ($entity_code)");
    }

    $self->{entity}       = $entity;
    $self->{entity_short} = $entity_code;
    $self->{jobstream}    = _entity_code( $self->{jobstream}, $entity_code );
}
     
#----------------#
sub entity_short {
#----------------#
    my ( $self, $jobstream ) = @_;


    if ( ref($self) eq 'Mx::Scheduler' ) {
        return $self->{entity_short};
    }
    else {
        return _entity_code( $jobstream );
    }
}


#-----------#
sub runtype {
#-----------#
    my ( $self, $jobstream ) = @_;


    if ( ref($self) eq 'Mx::Scheduler' ) {
        return $self->{runtype};
    }
    else {
        my $runtype_code = _runtype_code( $jobstream );
        return $RUNTYPES{$runtype_code};
    }
}


#---------------------#
sub _decode_jobstream {
#---------------------#
    my ( $self ) = @_;


    my $logger    = $self->{logger};
    my $jobstream = $self->{jobstream};

    my $pillar_code  = _pillar_code( $jobstream );
    my $entity_code  = _entity_code( $jobstream );
    my $runtype_code = _runtype_code( $jobstream );

    my $pillar;
    unless ( $pillar = $PILLARS{$pillar_code} ) {
        $logger->info("cannot extract the pillar from the jobstream name ($jobstream)");
        return;
    }
    $self->{pillar} = $pillar;
    $logger->info("pillar of the jobstream is '$pillar'");

    my $entity;
    unless ( $entity = $ENTITIES{$entity_code} ) {
        $logger->info("cannot extract the entity from the jobstream name ($jobstream)");
        return;
    }
    $self->{entity}       = $entity;
    $self->{entity_short} = $entity_code;
    $logger->info("entity of the jobstream is '$entity'");

    my $runtype;
    unless ( $runtype = $RUNTYPES{$runtype_code} ) {
        $logger->info("cannot extract the runtype from the jobstream name ($jobstream)");
        return;
    }
    $self->{runtype} = $runtype;
    $logger->info("runtype of the jobstream is '$runtype'");

    return 1;
}


#
# Args:
#
# pipe: name of the pipe
# item: string you want to write to the pipe
#
#---------#
sub write {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $pipe;
    unless ( $pipe = $args{pipe} ) {
        $logger->logdie("missing argument for write-call (pipe)");
    }

    my ( $label, $real_pipe ) = $pipe =~ /^(\w+):(\w+)$/;
    $real_pipe = $real_pipe || $pipe;

    my $item;
    unless ( $item = $args{item} ) {
        $logger->logdie("missing argument for write-call (item)");
    }
    chomp($item);

    my $pipe_directory = $self->{pipe_directory};

    if ( $label ) {
        $pipe_directory = $config->retrieve('PIPEDIR') . '/' . $label;
    }

    unless ( -d $pipe_directory ) {
        unless( mkdir( $pipe_directory ) ) {
            unless ( -d $pipe_directory ) { # might be created in the meantime by a parallel job
                $logger->logdie("cannot create directory $pipe_directory: $!");
            }
        }
    }

    my $pipe_file = $pipe_directory . '/' . $real_pipe;

    unless ( open PIPE, '>>', $pipe_file ) {
        $logger->logdie("cannot open pipefile $pipe_file for writing: $!");
    }

    print PIPE $item, "\n";

    close(PIPE);

    $logger->debug("item '$item' written to pipe $pipe");

    return 1;
}


#
# Args:
#
# pipe: name of the pipe
#
#--------#
sub read {
#--------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $pipe;
    unless ( $pipe = $args{pipe} ) {
        $logger->logdie("missing argument for read-call (pipe)");
    }

    my ( $label, $real_pipe ) = $pipe =~ /^(\w+):(\w+)$/;
    $real_pipe = $real_pipe || $pipe;

    my $pipe_directory = $self->{pipe_directory};

    if ( $label ) {
        $pipe_directory = $config->retrieve('PIPEDIR') . '/' . $label;
    }

    my $pipe_file = $pipe_directory . '/' . $real_pipe;

    unless ( open PIPE, '<', $pipe_file ) {
        $logger->logdie("cannot open pipefile $pipe_file for reading: $!");
    }

    my @items = <PIPE>;
 
    close(PIPE);

    $logger->debug("items read from pipe $pipe: @items");

    return @items;
}


#-----------#
sub cleanup {
#-----------#
    my ( $self, %args ) = @_;


    my $logger         = $self->{logger};
    my $config         = $self->{config};
    my $pipe           = $args{pipe};

#    unless ( exists $args{pipe} ) {
#        $logger->info("cleaning up complete pipe directory ($pipe_directory)");
#
#        return Mx::Util->rmdir( directory => $pipe_directory, logger => $logger );
#    }

    my ( $label, $real_pipe ) = $pipe =~ /^(\w+):(\w+)$/;
    $real_pipe = $real_pipe || $pipe;

    my $pipe_directory = $self->{pipe_directory};

    if ( $label ) {
        $pipe_directory = $config->retrieve('PIPEDIR') . '/' . $label;
    }

    my $pipe_file = $pipe_directory . '/' . $real_pipe;

    if ( -f $pipe_file ) {
        $logger->info("cleaning up pipe ($pipe_file)");
  
        unless ( unlink( $pipe_file ) ) {
            $logger->logdie("cannot cleanup pipe ($pipe_file): $!");
        }

        return 1;
    }
}


#---------------------#
sub entity_long2short {
#---------------------#
    my ( $class, $entity ) = @_;


    return $REVERSE_ENTITIES{$entity};
}


#---------------------#
sub entity_short2long {
#---------------------#
    my ( $class, $entity ) = @_;


    return $ENTITIES{$entity};
}

1;
