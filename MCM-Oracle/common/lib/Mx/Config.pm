package Mx::Config;

use strict;
no strict 'refs';
use warnings;

use Config::General;
use FileHandle;
use Carp;
use File::Spec;
use File::Basename;
use Hash::Flatten;
use XML::Simple;

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

my $XML_DECLARATION = '<?xml version="1.0" encoding="utf-8"?>';

#-------#
sub new {
#-------#
    my ( $class, $configfile ) = @_;


    $configfile ||= Mx::Config->configfile();

    my $config  = Config::General->new(
        -ConfigFile      => $configfile,
        -InterPolateVars => 1,
        -InterPolateEnv  => 1,
        -IncludeAgain    => 1
    );

    my %config = $config->getall();

    bless { config => \%config, configfile => $configfile }, $class;
}

#
# create a new Mx::Config object based on a configfile using another Mx::Config object ($self) as base.
#
#----------#
sub derive {
#----------#
    my ( $self, $configfile ) = @_;


    my $string;

    unless ( -f $configfile ) { 
        unless ( $configfile = $self->retrieve( $configfile, 1 ) ) {
            croak "$configfile is not a file and not a configuration key";
        }
    }

    my $fh;
    unless ( $fh = FileHandle->new( $configfile, '<' ) ) {
        croak "cannot open $configfile: $!";
    }

    while ( my $line = <$fh> ) {
        if ( my ( $key, $value ) = $line =~ /^\s*(\w+)\s*=\s*(.*)$/ ) {
            $value =~ s/\s+$//;

            $value =~ s/\$(\w+)/$self->retrieve($1)/eg;

            if ( $value =~ /\./ ) {
                $value = $self->retrieve( $value, 1 ) || $value;
            }

            $string .= "$key = $value\n";
        }
        else {
            $string .= $line;
        }
    }

    $fh->close();

    my $string_fh = FileHandle->new( \$string, '<' );

    my $config  = Config::General->new(
        -ConfigFile            => $string_fh,
        -InterPolateVars       => 1,
        -InterPolateEnv        => 1,
        -MergeDuplicateOptions => 1,
        -IncludeAgain          => 1
    );

    my %config = $config->getall();

    bless { config => \%config, configfile => $configfile }, ref( $self );
}

#
# Auto-defines accessors for all the configuration keys
#
#------------#
sub AUTOLOAD {
#------------#
    my ( $self ) = @_;


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
# This allows for the syntax retrieve( ACCOUNTS.murexconfig.encrypted_password )
# The corresponding value can also be a similar expression (using % instead of . as separator)
#
#------------#
sub retrieve {
#------------#
    my ( $self, $key, $no_strict ) = @_;


    my $value;

    if ( exists $self->{config}->{$key} ) {
        $value = $self->{config}->{$key};
    }
    elsif ( $key =~ /\./ ) {
        my @parts = split /\./, $key;

        $value = $self->{config}; my $found = 0;
        while ( @parts ) {
           $found = 0;
           for ( my $i = $#parts; $i >= 0; $i-- ) {
                my $key = join '.', @parts[0..$i];

                if ( exists $value->{$key} ) {
                    $found = 1;
                    $value = $value->{$key};
                    @parts = @parts[($i + 1)..$#parts];
                    last;
                }
            }

            last unless $found;
        }

        unless ( $found ) {
            return if $no_strict;
            croak("using non-existing configuration parameter: $key");
        }
    }
    elsif ( my $service = $SERVICE_KEYS{$key} ) {
        my $location = $self->{config}->{SERVICES}->{$service}->{location};
        if ( defined $location ) {
            my $app_srv  = $self->{config}->{APP_SRV};
            my @app_servers = ( ref( $app_srv ) eq 'ARRAY' ) ? @{ $app_srv } : ( $app_srv );

            return $app_servers[$location];
        }

        croak("location of service $service unknown");
    }
    else {
        return if $no_strict;
        croak("using non-existing configuration parameter: $key");
    }

    #
    # it's a special value
    #
    if ( $value =~ /%/ ) {
        my $orig_value = $value;
        my @parts = split /%/, $value;
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

#---------------------------#
sub retrieve_project_logdir {
#---------------------------#
    my ( $self, $project ) = @_;


    my $nfsdatadir = $self->retrieve('PROJECT_NFSDATADIR');
    return "$nfsdatadir/$project/log";
}

#---------------------------#
sub retrieve_project_rundir {
#---------------------------#
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
    unless ( $fh = FileHandle->new( $envfile, '<' ) ) {
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
    unless ( $fh = FileHandle->new( $envfile, '<' ) ) {
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
    my ( $class ) = @_;


    my $configfile = $CONFIGDIR . '/' . $ENV{MXENV} . '.cfg';
    my $fh;
    unless ( $fh = FileHandle->new( $configfile, '<' ) ) {
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

#--------#
sub hash {
#--------#
    my ( $self ) = @_;


    unless ( $self->{hash} ) {
        my $flatter = Hash::Flatten->new();

        $self->{hash} = $flatter->unflatten( $self->{config} );
    }

    return $self->{hash};
}

#--------#
sub dump {
#--------#
    my ( $self, $file ) = @_;


    if ( ! $file ) {
        $file = $self->{configfile};
        my ( $extension ) = $file =~ /\.(\w+)$/;
        if ( $extension && $extension ne 'xml' ) {
            $file =~ s/\.(\w+)$/.xml/;
        }
        else {
            croak 'cannot decide on destination file for dump';
        }
    }

    my $fh;
    unless ( $fh = FileHandle->new( $file, '>' ) ) {
        croak "unable to open $file: $!";
    }

    my $xs = XML::Simple->new( NoAttr => 1, KeyAttr => [], RootName => 'Configuration', XMLDecl => $XML_DECLARATION );

    my $xml = $xs->XMLout( $self->{config} );

    print $fh $xml;

    $fh->close;
}

1;

