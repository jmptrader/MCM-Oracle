package Mx::Audit;

use strict;
use warnings;

use Mx::Env;
use Carp;
use IO::File;
use Sys::Hostname;

#
# FORMAT: start/end;timestamp;pid;hostname;env;username;exitcode;message;
#
use constant AUDIT_FORMAT => "%5s;%17s;%5s;%10s;%12s;%9s;%3s;%s\n";

use constant INITIALIZED => 1;
use constant STARTED     => 2;
use constant ENDED       => 3;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    my @required_args = qw(directory keyword);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in initialisation of audit object ($arg)");
        }
    }
    unless ( ref( $args{keyword} ) eq 'ARRAY' ) {
        $args{keyword} = [ $args{keyword} ];
    }
    my $auditfile = _filename( $args{directory}, @{ $args{keyword} } );
    my $fh;
    unless ( $fh = IO::File->new( $auditfile, '>>' ) ) {
        $logger->error("cannot open auditfile ($auditfile): $!");
        return;
    }
    $logger->debug("auditfile opened ($auditfile)");
    bless {
        filename => $auditfile,
        fh       => $fh,
        username => getpwuid($<),
        hostname => hostname(),
        pid      => $$,
        env      => $ENV{MXENV},
        logger   => $logger,
        message  => undef,
        status   => INITIALIZED,
        begin    => undef,
        end      => undef,
    }, $class;
}

#
# Mark the start of 'something' in the audit file.
#
#---------#
sub start {
#---------#
    my ( $self, $message ) = @_;

    $message ||= '';
    $self->{message} = $message;
    $self->{begin}   = _timestamp();
    my $line = sprintf AUDIT_FORMAT, 'start', $self->{begin}, $self->{pid}, $self->{hostname}, $self->{env}, $self->{username}, '', $message;
    my $fh = $self->{fh};
    if ( print $fh $line ) {
        $self->{logger}->debug('marked start in auditfile');
        $self->{status} = STARTED;
        return 1;
    }
    else {
        $self->{logger}->error("could not mark start in auditfile: $!");
        return;
    }
}

#
# Mark the end of 'something' in the audit file and exit
#
#-------#
sub end {
#-------#
    my ( $self, $message, $exitcode, %args ) = @_;


    $message ||= '';
    $self->{end} = _timestamp();

    my $line = sprintf AUDIT_FORMAT, 'end', $self->{end}, $self->{pid}, $self->{hostname}, $self->{env}, $self->{username}, $exitcode, $message;

    my $fh = $self->{fh};
    if ( print $fh $line ) {
        ( $exitcode == 0 ) ? $self->{logger}->info($message) : $self->{logger}->fatal($message);
        $self->{logger}->debug('marked end in auditfile');
        $self->{status} = ENDED;
    }
    else {
        ( $exitcode == 0 ) ? $self->{logger}->info($message) : $self->{logger}->fatal($message);
        $self->{logger}->error("could not mark end in auditfile: $!");
    }
    $fh->close;

    $args{sybase}->close() if( defined $args{sybase} );

    print( $message, "\n" ) if( $args{echo} );

    #
    # compensate for the fact that TWS cannot correctly handle returncodes where % 256 == 0
    #
    if ( $exitcode != 0 and $exitcode % 256 == 0 ) {
        $exitcode++;
    }

    exit $exitcode;
}

#
# This private function is used to come up with a name for the auditfile, based on the provided keyword(s).
#
#-------------#
sub _filename {
#-------------#
    my ( $auditdir, @keywords ) = @_;

    -d $auditdir or croak "$auditdir is not a directory";
    my $filename = $auditdir . '/';
    $filename .= join '_', @keywords;
    $filename .= '.aud';

    return $filename;
}

#
# Generate a timestamp in a standard format
#
#--------------#
sub _timestamp {
#--------------#
    my ( $sec, $min, $hour, $day, $month, $year ) = ( localtime() )[ 0 .. 5 ];
    sprintf "%04s%02s%02s %02s:%02s:%02s", $year + 1900, ++$month, $day, $hour,
      $min, $sec;
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
