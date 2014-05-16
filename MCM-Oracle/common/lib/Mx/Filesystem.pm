package Mx::Filesystem;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;
use Filesys::Statvfs;

#
# Attributes:
#
# name                     name of the filesystem
# mountpoint               directory where the filesystem is mounted
# type                     see below
# alert                    must the filesystem be monitored
# historize                must the filesystem be graphed
# warning_threshold
# fail_threshold
# 
# size                     size of the filesystem in KB
# used                     amount of space used in KB
# available                amount of space available in KB
# percent_used             percentage of the filesystem used
# timestamp
# status
#

our $TYPE_NFS           = 'nfs';
our $TYPE_LOCAL         = 'local';
our $TYPE_LOCAL_SOLARIS = 'local_solaris';
our $TYPE_LOCAL_LINUX   = 'local_linux';

our $STATUS_UNKNOWN     = 'unknown';
our $STATUS_OK          = 'ok';
our $STATUS_NOK         = 'nok';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $self->{logger} = $args{logger} or croak 'no logger defined';

    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex filesystem (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex filesystem (config)");
    }

    my $fs_configfile = $config->retrieve('FS_CONFIGFILE');
    my $fs_config     = Mx::Config->new( $fs_configfile );
 
    my $filesystem_ref;
    unless ( $filesystem_ref = $fs_config->retrieve("%FILESYSTEMS%$name") ) {
        $logger->logdie("filesystem '$name' is not defined in the configuration file");
    }
 
    foreach my $param (qw( mountpoint type alert historize warning_threshold fail_threshold )) {
        unless ( exists $filesystem_ref->{$param} ) {
            $logger->logdie("parameter '$param' for filesystem '$name' is not defined in the configuration file");
        }
        $self->{$param} = $filesystem_ref->{$param};
    }

    unless ( $self->{type} eq $TYPE_NFS or $self->{type} eq $TYPE_LOCAL or $self->{type} eq $TYPE_LOCAL_SOLARIS or $self->{type} eq $TYPE_LOCAL_LINUX ) {
        $logger->error("filesystem '$name' has an invalid type: " . $self->{type});
        return;
    }

    if ( $args{historize} ) {
        return unless $self->{historize};
    }

    if ( my $type = $args{type} ) {
        if ( $type eq $TYPE_NFS ) {
            return unless $self->{type} eq $TYPE_NFS;
        }
        elsif ( $type eq $TYPE_LOCAL ) {
            if ( $^O eq 'solaris' ) {
                return unless ( $self->{type} eq $TYPE_LOCAL or $self->{type} eq $TYPE_LOCAL_SOLARIS );
            } 
            elsif ( $^O eq 'linux' ) {
                return unless ( $self->{type} eq $TYPE_LOCAL or $self->{type} eq $TYPE_LOCAL_LINUX );
            }
        }
        elsif ( $type eq $TYPE_LOCAL_SOLARIS ) {
            return unless ( $self->{type} eq $TYPE_LOCAL or $self->{type} eq $TYPE_LOCAL_SOLARIS );
        }
        elsif ( $type eq $TYPE_LOCAL_LINUX ) {
            return unless ( $self->{type} eq $TYPE_LOCAL or $self->{type} eq $TYPE_LOCAL_LINUX );
        }
    }

    $self->{status} = $STATUS_UNKNOWN;

    $logger->debug("filesystem '$name' initialized");
 
    bless $self, $class;
}


#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my @filesystems = ();
 
    my $logger = $args{logger} or croak 'no logger defined';
 
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $fs_configfile = $config->retrieve('FS_CONFIGFILE');
    my $fs_config     = Mx::Config->new( $fs_configfile );
 
    $logger->debug('scanning the configuration file for filesystems');
 
    my $filesystems_ref;
    unless ( $filesystems_ref = $fs_config->FILESYSTEMS ) {
        $logger->logdie("cannot access the filesystems section in the configuration file");
    }
 
    foreach my $name ( keys %{$filesystems_ref} ) {
        if ( my $filesystem = Mx::Filesystem->new( name => $name, config => $config, logger => $logger, type => $args{type}, historize => $args{historize} ) ) {
            push @filesystems, $filesystem;
        }
    }
 
    return @filesystems;
}

#----------#
sub update {
#----------#
    my ( $self, %args ) = @_;


    my $logger     = $self->{logger};
    my $name       = $self->{name};
    my $mountpoint = $self->{mountpoint};

    my $block_size; my $total_nr_blocks; my $free_nr_blocks; my $available_nr_blocks;
    unless ( (undef, $block_size, $total_nr_blocks, $free_nr_blocks, $available_nr_blocks) = statvfs( $mountpoint ) ) {
        $logger->error("cannot update the size of filesystem '$name': $!");
        $self->{status} = $STATUS_NOK;
        return;
    }

    $self->{timestamp}    = time();
    $self->{status}       = $STATUS_OK;
    $self->{size}         = $total_nr_blocks * $block_size / 1024;
    $self->{available}    = $available_nr_blocks * $block_size / 1024;
    $self->{free}         = $free_nr_blocks * $block_size / 1024;
    $self->{used}         = ( $total_nr_blocks - $free_nr_blocks ) * $block_size / 1024;
    $self->{percent_used} = sprintf "%.2f", ( $self->{used} / $self->{size} * 100 );

    return 1;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;
 
    return $self->{name};
}


#--------------#
sub mountpoint {
#---------------#
    my ( $self ) = @_;
 
    return $self->{mountpoint};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;
 
    return $self->{type};
}

#--------#
sub size {
#--------#
    my ( $self ) = @_;
 
    return $self->{size};
}

#--------#
sub used {
#--------#
    my ( $self ) = @_;
 
    return $self->{used};
}

#----------------#
sub percent_used {
#----------------#
    my ( $self ) = @_;
 
    return $self->{percent_used};
}

#-------------#
sub available {
#-------------#
    my ( $self ) = @_;
 
    return $self->{available};
}

#--------#
sub free {
#--------#
    my ( $self ) = @_;
 
    return $self->{free};
}

#---------#
sub alert {
#---------#
    my ( $self ) = @_;
 
    return $self->{alert};
}

#-------------#
sub historize {
#-------------#
    my ( $self ) = @_;
 
    return $self->{historize};
}

#-------------#
sub timestamp {
#-------------#
    my ( $self ) = @_;
 
    return $self->{timestamp};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;
 
    return $self->{status};
}

#---------------------#
sub warning_threshold {
#---------------------#
    my ( $self ) = @_;
 
    return $self->{warning_threshold};
}

#------------------#
sub fail_threshold {
#------------------#
    my ( $self ) = @_;
 
    return $self->{fail_threshold};
}

#-----------------------------#
sub prepare_for_serialization {
#-----------------------------#
    my ( $self, %args ) = @_;


    $self->{logger} = undef;
    $self->{config} = undef;
}

#-------------------------------#
sub unprepare_for_serialization {
#-------------------------------#
    my ( $self, %args ) = @_;


    $self->{logger} = $args{logger};
    $self->{config} = $args{config};
}

1;
