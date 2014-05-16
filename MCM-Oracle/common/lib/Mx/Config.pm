package Mx::Config;

use strict;
no strict 'refs';
use warnings;

use Config::General;
use IO::File;
use Carp;
use File::Spec;
use File::Basename;

use vars qw($AUTOLOAD);

my $CONFIGDIR = '/lch/fxclear/' . $ENV{MXUSER} . '/projects/common/conf';

my %SERVICE_KEYS = (
  MXJ_FILESERVER_HOST => 'fileserver',
  MXJ_XMLSERVER_HOST  => 'xmlserver',
  MXJ_MXNET_HOST      => 'murexnet',
  MXJ_DOC_SERVER      => 'docserver',
  RTBS_HOST           => 'rtbs',
  RTBS_FIXING_HOST    => 'rtbs fixing'
);

#-------#
sub new {
#-------#
    my ($class, $configfile) = @_;

    my $config  = Config::General->new(
        -ConfigFile      => $configfile || Mx::Config->configfile(),
        -InterPolateVars => 1,
        -InterPolateEnv  => 1,
        -IncludeAgain    => 1
    );
    my %config = $config->getall();
    bless { config => \%config }, $class;
}


#
# Auto-defines accessors for all the configuration keys
#
#------------#
sub AUTOLOAD {
#------------#
    my ($self) = @_;


    return if $AUTOLOAD =~ /DESTROY$/;

    my ($name) = $AUTOLOAD =~ /([^:]+)$/;

    *$name = sub {
        my $self = shift;
        $self->{config}->{$name} = shift if @_;
        return $self->retrieve( $name );
    };

    goto &$name;
}

#
# More advanced retrieval method than the AUTOLOADER.
# This allows for the syntax retrieve(%ACCOUNTS%murexconfig%encrypted_password)
# The corresponding value can also be a similar expression
#
#------------#
sub retrieve {
#------------#
    my ($self, $key, $no_strict) = @_;


    my $value; 

    #
    # it's a special key...
    #
    if ( $key =~ /^%(.+)$/ ) {
        my @parts = split '%', $1;
        $value = $self->{config};
        foreach my $part ( @parts ) {
            if ( exists $value->{$part} ) {
                $value = $value->{$part} 
            }
            else {
                return if $no_strict;
                croak("using non-existing configuration parameter: $key");
            }
        }
    }
    elsif ( my $service = $SERVICE_KEYS{$key} ) {
        my $location = $self->{config}->{SERVICES}->{$service}->{location};
        my $app_srv  = $self->{config}->{APP_SRV};
        my @app_servers = ( ref( $app_srv ) eq 'ARRAY' ) ? @{ $app_srv } : ( $app_srv );

        return $app_servers[$location];
    }
    #
    # it's a normal key
    #
    else {
        unless ( exists $self->{config}->{$key} ) {
            return if $no_strict;
            croak("using non-existing configuration parameter: $key");
        }
        $value = $self->{config}->{$key};
    }

    #
    # it's a special value
    #
    if ( $value =~ /^%(.+)$/ ) {
        my $orig_value = $value;
        my @parts = split '%', $1; 
        $value = $self->{config};
        foreach my $part ( @parts ) {
            if ( exists $value->{$part} ) {
                $value = $value->{$part} 
            }
            else {
                return if $no_strict;
                croak("using non-existing configuration parameter: $orig_value");
            }
        }
    }

    #
    # all '$' are replaced by a simple $
    # all \n are replaced by real newlines
    #
    $value =~ s/'\$'/\$/g;
    $value =~ s/\\n/\n/g;

    return $value;
}

#---------------------#
sub retrieve_as_array {
#---------------------#
    my ( $self, $key, $no_strict ) = @_;


    if ( my $value = $self->retrieve( $key, $no_strict ) ) {
        if ( ref( $value ) eq 'ARRAY' ) {
            return @{ $value };
        }
		return ( ( $value ) );
    }
    return ();
}

#-----------------#
sub add_to_config {
#-----------------#
    my ( $self, %hash ) = @_;


    my $configref = $self->{config};
    while ( my ($key, $value ) = each %hash ) {
        $configref->{$key} = $value;
    }
}


#-------------------------#
sub get_project_variables {
#-------------------------#
    my ( $self, $project ) = @_;


    my $project_directory;                                                                                                                                                                              
    if ( $project ) {
        $project_directory = $self->retrieve('PROJECT_DIR') . '/' . $project;
    }
    else {
        $project_directory = dirname( File::Spec->rel2abs( $0 ) );
 
        $project_directory =~ s/\/bin$//;
        $project_directory =~ s/\/script$//;
 
        ( undef, $project ) = $project_directory =~ /\/(kbc-scripts|framework)\/([^\/]+)$/;

        unless ( $project ) {
            ( $project ) = $project_directory =~ /\/kbc\/([^\/]+)$/;
        }
    }

    my $localdatadir = $self->retrieve('PROJECT_LOCALDATADIR');
    my $nfsdatadir   = $self->retrieve('PROJECT_NFSDATADIR');
    my $archdir      = $self->retrieve('PROJECT_ARCHDIR');

    my ($day, $month, $year) = ( localtime() )[3..5];
    my $date = sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;

    my $transferdir = "$nfsdatadir/$project/transfer";
    if ( -d $transferdir ) {
        my $symlink = $transferdir . '/today';
        $transferdir .= "/$date";
        unless ( -d $transferdir ) {
            unless ( mkdir( $transferdir ) ) {
                unless ( -d $transferdir ) { # might be created in the meantime by a parallel job
                    croak "cannot create $transferdir: $!";
                }
            }
            unlink $symlink;
            symlink $date, $symlink;
        }
    }

    my $hash = {
      PROJECT             => $project,
      PROJECT_BINDIR      => "$project_directory/bin",
      PROJECT_LIBDIR      => "$project_directory/lib",
      PROJECT_XMLDIR      => "$project_directory/xml",
      PROJECT_SQLDIR      => "$project_directory/sql",
      PROJECT_CONFDIR     => "$project_directory/conf",
      PROJECT_LOGDIR      => "$nfsdatadir/$project/log",
      LOGDIR              => "$nfsdatadir/$project/log",
      PROJECT_DATADIR     => "$localdatadir/$project/data",
      PROJECT_NFSDATADIR  => "$nfsdatadir/$project/data",
      PROJECT_TMPDIR      => "$localdatadir/$project/tmp",
      PROJECT_RUNDIR      => "$nfsdatadir/$project/run",
      RUNDIR              => "$nfsdatadir/$project/run",
      PROJECT_TRANSFERDIR => "$transferdir",
      PEOJECT_ARCHDIR     => "$archdir/$project/arch",
   };

   return $hash;

}

#-------------------------#
sub set_project_variables {
#-------------------------#
    my ( $self, $project ) = @_;

 
    my $hash = $self->get_project_variables( $project );

    $self->add_to_config( %{$hash} );
}

#-----------------------#
sub retrieve_lch_logdir {
#-----------------------#
    my ( $self, $project ) = @_;


    my $nfsdatadir = $self->retrieve('PROJECT_NFSDATADIR');
    return "$nfsdatadir/$project/log";
}

#-----------------------#
sub retrieve_lch_rundir {
#-----------------------#
    my ( $self, $project ) = @_;


    my $nfsdatadir = $self->retrieve('PROJECT_NFSDATADIR');
    return "$nfsdatadir/$project/run";
}

#
# return a list of all known environments
#
#----------------#
sub environments {
#----------------#
    my ( $class, $hostname ) = @_;

    my %list;
    my $envfile = $CONFIGDIR . '/environments.cfg';
    my $fh;
    unless ( $fh = IO::File->new( $envfile, '<' ) ) {
        croak "cannot locate environment file ($envfile)";
    }
    while ( my $line = <$fh> ) {
        if ( $line =~ /^(\w+):(\w+):(\S+)/ ) {
            my $env     = $1;
            my $servers = $3;
            if ( $hostname ) {
                my @servers = split ',', $servers;
                if ( grep /^$hostname$/, @servers ) {
                    $list{$env} = 1;
                }
            }
            else {
                $list{$env} = 1;
            }
        }
    }
    $fh->close;
    return keys %list;
}

#---------#
sub users {
#---------#
    my ( $class, $hostname ) = @_;

    my %list;
    my $envfile = $CONFIGDIR . '/environments.cfg';
    my $fh;
    unless ( $fh = IO::File->new( $envfile, '<' ) ) {
        croak "cannot locate environment file ($envfile)";
    }
    while ( my $line = <$fh> ) {
        if ( $line =~ /^(\w+):(\w+):(\S+)/ ) {
            my $env     = $1;
            my $user    = $2;
            my @servers = split ',', $3;
            if ( grep /^$hostname$/, @servers ) {
                $list{$user} = $env;
            }
        }
    }
    $fh->close;
    return %list;
}

#
# return the name of the environment specific configuration file
#
#--------------#
sub configfile {
#--------------#
    my ($class) = @_;

    my $configfile = $CONFIGDIR . '/' . $ENV{MXENV} . '.cfg';
    my $fh;
    unless ( $fh = IO::File->new( $configfile, '<' ) ) {
        croak "cannot locate local configuration file ($configfile)";
    }
    $fh->close;
    return $configfile;
}

#------------#
sub get_keys {
#------------#
    my ( $self ) = @_;

    return keys %{$self->{config}};
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

