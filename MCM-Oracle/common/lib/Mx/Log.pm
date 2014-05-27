package Mx::Log;

use strict;
use warnings;

use Mx::Env;
use Log::Log4perl qw(:no_extra_logdie_message);
use Logfile::Rotate;
use File::Basename;
use Carp;

use constant ROTATE_COUNT    => 7;
use constant ROTATE_COMPRESS => 0;

#-------#
sub new {
#-------#
    my ( $class, %args) = @_;


    unless ( $args{filename} ) {
        my @required_args = qw(directory keyword);
        foreach my $arg (@required_args) {
            unless ( $args{$arg} ) {
                croak "missing argument in initialisation of log object ($arg)";
            }
        } 
        unless ( ref( $args{keyword} ) eq 'ARRAY' ) {
            $args{keyword} = [ $args{keyword} ];
        }
    }
    #
    # To compensate for the fact that this is a wrapper class around Log4perl - this means that the caller depth is changed
    # (and thus wrong data will be generated for %F, %C and %L in patterns) - we increase caller_depth by one.
    #
    $Log::Log4perl::caller_depth++;

    my $filename = $args{filename} || _filename( $args{directory}, $args{no_date}, @{$args{keyword}} );
    my %settings = (
        'log4perl.rootLogger'                => 'DEBUG, LOGFILE',
        'log4perl.category.rrdtool'          => 'WARN, LOGFILE',
        'log4perl.category.RRDTool.OO'       => 'WARN, LOGFILE',
        'log4perl.appender.LOGFILE'          => 'Log::Log4perl::Appender::File',
        'log4perl.appender.LOGFILE.filename' => $filename,
        'log4perl.appender.LOGFILE.layout'   => 'PatternLayout',
        'log4perl.appender.LOGFILE.layout.ConversionPattern' =>
          '[%d] %-20F{1} %-5p - %-6P - %m%n',
    );

    if ( my $weblog = $ENV{MXWEBLOG} ) {
        $settings{'log4perl.rootLogger'}                                .= ', LOGFILE2';
        $settings{'log4perl.appender.LOGFILE2'}                          = 'Log::Log4perl::Appender::File';
        $settings{'log4perl.appender.LOGFILE2.filename'}                 = $weblog;
        $settings{'log4perl.appender.LOGFILE2.layout'}                   = 'PatternLayout';
        $settings{'log4perl.appender.LOGFILE2.layout.ConversionPattern'} = '[%d] %-20F{1} %-5p - %-6P - %m%n';
    }

    Log::Log4perl->init_once( \%settings );
    my $logger = Log::Log4perl->get_logger();
    my $object = bless { real_logger => $logger, filename => $filename, weblog => $ENV{MXWEBLOG} }, $class;

#
# We have to pollute the caller's namespace to make sure that routines that do not have this object passed
# as argument (e.g. syb_err_handler in Mx::Sybase) can still access it via the global variable $_default_logger.
#
    $main::_default_logger = $object;
    return $object;
}

#
# Again, as this is a wrapper class, we relay all method calls to the 'real' logger object
#
#------------#
sub AUTOLOAD {
#------------#
    no strict;
    my $self = shift;
    $AUTOLOAD =~ s/.*:://;
    return if $AUTOLOAD eq 'DESTROY';
    $AUTOLOAD = 'logconfess' if $AUTOLOAD eq 'logdie';
    $self->{real_logger}->$AUTOLOAD(@_);
}

#-----------#
sub DESTROY {
#-----------#
    my ( $self ) = @_;

    if ( my $weblog = $self->{weblog} ) {
        if ( open FH, ">>$weblog" ) {
            print FH "---";
            close(FH);
        }
    }
}

#------------#
sub filename {
#------------#
    my ( $self ) = @_;

    return $self->{filename};
}

#-------------#
sub directory {
#-------------#
    my ( $self ) = @_;

    return dirname( $self->{filename} );
}

#
# Possible arguments:
#
# count:     number of versions to keep (default is ROTATE_COUNT)
# compress:  if the old logfiles must be compressed or not (default is ROTATE_COMPRESS)
# directory: move the old logfile to this directory
#
#----------#
sub rotate {
#----------#
    my ( $self, %args ) = @_;


    my $filename;
    if ( ref($self) eq 'Mx::Log' ) {
        $filename = $self->{filename};
    }
    else {
        $filename = $args{filename};
    }

    unless ( $filename ) {
        croak 'rotate: no filename specified';
    }

    my $count     = ( exists $args{count} )    ? $args{count}    : ROTATE_COUNT;
    my $compress  = ( exists $args{compress} ) ? $args{compress} : ROTATE_COMPRESS;
    my $directory = $args{directory};

    my %props = (
        File    => $filename,
        Flock   => 'yes',
        Persist => 'no'
    );

    $props{Count} = $count if $count;
    $props{Gzip}  = ( $compress ) ? 'lib' : 'no';
    $props{Dir}   = $directory if $directory;

    if ( my $log = new Logfile::Rotate( %props ) ) {
        $log->rotate();
    }
}

#-----------------#
sub create_logdir {
#-----------------#
    my ( $class, %args ) = @_;


    my $logdir  = $args{directory};
    my $no_date = $args{no_date} || 0;

    -d $logdir or croak "$logdir is not a directory";
 
    my $full_logdir = $logdir;
    my $date;
    unless ( $no_date ) {
        my ($day, $month, $year) = ( localtime() )[3..5];
        $date = sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;
        $full_logdir .= "/$date";
    }

    unless ( -d $full_logdir ) {
        unless ( mkdir( $full_logdir ) ) {
            unless ( -d $full_logdir ) { # might be created in the meantime by a parallel job
                croak "cannot create $full_logdir: $!";
            }
        }

        unless ( $no_date ) {
            my $symlink = $logdir . '/today';
            unlink $symlink;
            symlink $date, $symlink;
        }
    }

    return $full_logdir;
}

#
# This private function is used to come up with a name for the logfile, based on the provided keywords.
#
#-------------#
sub _filename {
#-------------#
    my ( $logdir, $no_date, @keywords ) = @_;


    my $full_logdir = Mx::Log->create_logdir( directory => $logdir, no_date => $no_date );

    my $filename = $full_logdir . '/';
    $filename .= join '_', @keywords;
    $filename .= '.log';

    return $filename;
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

