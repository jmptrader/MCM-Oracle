package Mx::XMLConfig;

use strict;
no strict 'refs';
use warnings;

use XML::Simple;
use Hash::Flatten;
use Hash::Merge;
use IO::File;
use File::Basename;
use Carp;

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
    my ($class, $configfile) = @_;


    $configfile ||= Mx::XMLConfig->configfile();

    my $hashref = _parse_configfile( $configfile );

    my $includes = [];
    if ( $hashref->{Include} ) {
        $includes = ( ref ( $hashref->{Include} ) eq 'ARRAY' ) ? $hashref->{Include} : [ $hashref->{Include} ];
    }

    delete $hashref->{Include};

    my $configdir = dirname( $configfile );

    foreach my $include ( @{$includes} ) {
        unless ( substr( $include, 0, 1 ) eq '/' ) {
            $include = $configdir . '/' . $include;
        }
    }

    bless { config => $hashref, includes => $includes, configfile => $configfile }, $class;
}

#---------------------#
sub _parse_configfile {
#---------------------#
    my ( $configfile ) = @_;


    my $xs      = XML::Simple->new( ForceArray => [ 'Include' ] );
    my $flatter = Hash::Flatten->new();
    my $merger  = Hash::Merge->new( 'LEFT_PRECEDENT' );

    my $configdir = dirname( $configfile );

    my $hashref = eval { $xs->XMLin( $configfile ) };

    croak "parsing of $configfile failed: $@" if $@;

    my $flat_hashref = $flatter->flatten( $hashref );

    _transform_arrays( $flat_hashref );

    if ( $flat_hashref->{Include} ) {
        foreach my $configfile ( @{$flat_hashref->{Include}} ) {
            unless ( substr( $configfile, 0, 1 ) eq '/' ) {
                $configfile = $configdir . '/' . $configfile;
            }

            $flat_hashref = $merger->merge( $flat_hashref, _parse_configfile( $configfile ) ); 
        }
    }

    return $flat_hashref;
}

#---------------------#
sub _transform_arrays {
#---------------------#
    my ( $hashref ) = @_;


    my %array_keys = ();
    foreach ( keys %{$hashref} ) {
        if ( /^(.+):(\d+)$/ ) {
            push @{$array_keys{$1}}, $2;
        }
    }

    while ( my ( $key, $value ) = each %array_keys ) {
        my @array = ();
        foreach my $number ( sort { $a <=> $b } @{$value} ) {
            push @array, $hashref->{"$key:$number"};

            delete $hashref->{"$key:$number"};
        }

        $hashref->{$key} = \@array;
    }
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

#------------#
sub retrieve {
#------------#
    my ($self, $key, $no_strict) = @_;


    unless ( exists $self->{config}->{$key} ) {
        return if $no_strict;
        croak("using non-existing configuration parameter: $key");
    }

    return $self->{config}->{$key};
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


    while ( my ($key, $value ) = each %hash ) {
        $self->{config}->{$key} = $value;
    }
}

#
# return the name of the environment specific configuration file
#
#--------------#
sub configfile {
#--------------#
    my ($class) = @_;


    my $configfile = $CONFIGDIR . '/' . $ENV{MXENV} . '.xml';

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

#-------------#
sub check_key {
#-------------#
    my ( $self, $key ) = @_;


    exists $self->{config}->{$key};
}

#-----------#
sub set_key {
#-----------#
    my ( $self, $key, $value ) = @_;


    $self->{config}->{$key} = $value;
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

#------------#
sub includes {
#------------#
    my ( $self ) = @_;


    return @{$self->{includes}};
}

#--------#
sub dump {
#--------#
    my ( $self, $file ) = @_;


    $file ||= $self->{configfile};

    my $fh;
    unless ( $fh = IO::File->new( $file, '>' ) ) {
        croak "unable to open $file: $!";
    }

    my $xs = XML::Simple->new( NoAttr => 1, KeyAttr => [], RootName => 'Configuration', XMLDecl => $XML_DECLARATION );

    my $xml = $xs->XMLout( $self->hash );

    print $fh $xml;

    $fh->close;
}

1;
