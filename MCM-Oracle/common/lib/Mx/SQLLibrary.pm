package Mx::SQLLibrary;

use strict;
use warnings;

use SQL::Library;
use IO::File;
use Carp;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $file   = $args{file};

    unless ( my $fh = IO::File->new( $file, '<' ) ) {
        $logger->logdie("cannot locate SQL library ($file): $!");
    }

    my $library;
    unless ( $library = SQL::Library->new( { lib => $file } ) ) {
        $logger->logdie("cannot open SQL library ($file)");
    }

    $logger->debug("using SQL library $file");

    bless { library => $library, cache => {}, logger => $logger }, $class;
}

#
# Retrieves a statement from the library, based on a key.
#
#---------#
sub query {
#---------#
    my ( $self, $key, $map, $no_strict ) = @_;


    my $logger  = $self->{logger};
    my $library = $self->{library};
    my $cache   = $self->{cache};

    my $query = $cache->{$key};

    unless ( $query ) {
        $logger->debug("retrieving SQL statement '$key'");

        $query = $library->retr( $key );
    
        unless ( $query ) {
            if ( $no_strict ) {
                $logger->warn("cannot locate SQL statement '$key'");
                return;
            }

            $logger->logdie("cannot locate SQL statement '$key'");
        }

        chomp($query);

        $cache->{$key} = $query;
    }

    #
    # placeholder substitution for database object names (not values) if a map is passed in as hashref
    # 
    if ( $map && ref( $map ) eq 'HASH' ) {
        while ( $query =~ s/__([^_]\w+?[^_])__/$map->{$1}/gse ) {}
    }

    return $query;
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

