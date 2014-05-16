package Mx::User;

use strict;
use warnings;

use Carp;
use Mx::Env;
use Mx::Config;
use Mx::Util;
use BerkeleyDB;


#
# Attributes:
#
# name:               login 
# full_name:          full name
# max_sessions:       maximum nr of sessions the user is allowed to launch
# printer:            default printer of this user
# override:           boolean indicating if a user is allowed to login to a disabled Murex server
# web_access:         boolean indicating if a user has access to the web application
# password:           encrypted version of the password used to login to the web application
# logger:             a Mx::Log instance
# config:             a Mx::Config instance
# env:                list of environments to which the user has access
#


#-------#
sub new {
#-------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("missing argument in initialisation of user (name)");
    }
    $self->{name} = $name = lc($name);

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    $self->{config}       = $config;

    $self->{max_sessions} = ( exists $args{max_sessions} ) ? $args{max_sessions} : 1;
    $self->{printer}      = $args{printer} || '';
    $self->{override}     = ( $args{override} ) ? 1 : 0;
    $self->{full_name}    = $args{full_name} || ''; 
    $self->{web_access}   = ( $args{web_access} ) ? 1 : 0; 
    $self->{env}          = $args{env} || [];

    bless $self, $class;

    if ( $args{password} ) {
        $self->set_password( $args{password} );
    }

    return $self;
}

#------------#
sub retrieve {
#------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("missing argument in initialisation of user (name)");
    }
    $self->{name} = $name = lc($name);

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }

    my $userfile = $config->USERFILE;
    my %users;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }

    unless ( exists $users{$name} ) {
        $logger->debug("user $name does not exist");
        return;
    }

    $self->{name}   = $name;
    $self->{config} = $config;
    _read_db_value( $self, $users{$name} );
    untie %users;
    bless $self, $class;
}

#----------------#
sub retrieve_all {
#----------------#
    my ($class, %args) = @_;

    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;
    #
    # check the arguments
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    my $userfile = $config->USERFILE;
    my %users;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }
    my @list;
    foreach my $name ( keys %users ) {
        my $user = {};
        $user->{name}   = $name;
        $user->{config} = $config;
        _read_db_value( $user, $users{$name} );
        bless $user, $class;
        push @list, $user;
    }
    untie %users;
    return @list;
}

#-----------------------#
sub retrieve_full_names {
#-----------------------#
    my ($class, %args) = @_;

    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;
    #
    # check the arguments
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    my $userfile = $config->USERFILE;
    my %users;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }
    my %list;
    foreach my $name ( keys %users ) {
        my $user = {};
        _read_db_value( $user, $users{$name} );
        $list{$name} = $user->{full_name};
    }
    untie %users;
    return %list;
}

#----------#
sub insert {
#----------#
    my ( $self ) = @_;

    my $logger = $self->{logger};
    my $config = $self->{config};
    my %users;
    my $userfile = $config->USERFILE;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }
    my $name = $self->{name};
    if ( exists $users{$name} ) {
        $logger->error("cannot insert an already existing user ($name)");
        return;
    }
    $users{$name} = _create_db_value( $self );
    untie %users;
}

#----------#
sub update {
#----------#
    my ( $self ) = @_;
    
    my $logger = $self->{logger};
    my $config = $self->{config};
    my %users;
    my $userfile = $config->USERFILE;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }
    my $name = $self->{name};
    unless ( exists $users{$name} ) {
        $logger->error("cannot update a non-existing user ($name)");
        return;
    }
    $users{$name} = _create_db_value( $self );
    untie %users;
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;
    
    my $logger = $self->{logger};
    my $config = $self->{config};
    my %users;
    my $userfile = $config->USERFILE;
    unless ( tie %users, 'BerkeleyDB::Hash', -Filename => $userfile, -Flags => DB_CREATE ) {
        $logger->logdie("cannot open $userfile: $! $BerkeleyDB::Error");
    }
    my $name = $self->{name};
    delete $users{$name};
    untie %users;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#-------------#
sub full_name {
#-------------#
    my ( $self, $full_name ) = @_;

    $self->{full_name} = $full_name if defined $full_name;
    return $self->{full_name};
}

#----------------#
sub max_sessions {
#----------------#
    my ( $self, $max_sessions ) = @_;

    $self->{max_sessions} = $max_sessions if defined $max_sessions; 
    return $self->{max_sessions};
}

#------------#
sub override {
#------------#
    my ( $self, $override ) = @_;

    $self->{override} = $override if defined $override;
    return $self->{override};
}

#-----------#
sub printer {
#-----------#
    my ( $self, $printer ) = @_;

    $self->{printer} = $printer if defined $printer;
    return $self->{printer};
}

#--------------#
sub web_access {
#--------------#
    my ( $self, $web_access ) = @_;

    $self->{web_access} = $web_access if defined $web_access;
    return $self->{web_access};
}

#-------#
sub env {
#-------#
    my ( $self, @list ) = @_;

    $self->{env} = [ @list ] if @list;
    return @{$self->{env}};
}

#----------------#
sub set_password {
#----------------#
    my ( $self, $password ) = @_;

    my $salt = join '', ('.','/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    $self->{password} = crypt( $password, $salt );
}

#------------------#
sub check_password {
#------------------#
    my ( $self, $password ) = @_;

    my $encrypted_password = $self->{password};
    $password = crypt($password, $encrypted_password);
    if ( $password eq $encrypted_password ) {
        return 1;
    }
    return 0;
}

#-------------#
sub check_env {
#-------------#
    my ( $self, $env ) = @_;

    $env ||= $ENV{MXENV};
    my @envs = $self->env();
    return grep /^$env$/, @envs;
}

#--------------------#
sub _create_db_value {
#--------------------#
    my ( $self, $map_ref ) = @_;
   
    my $env = join '#', sort @{$self->{env}};
    return join ':', ( $self->{max_sessions}, $self->{printer}, $self->{override}, $self->{full_name}, $self->{web_access}, $self->{password}, $env );
}

#------------------#
sub _read_db_value {
#------------------#
    my ( $self, $value ) = @_;

    my ($max_sessions, $printer, $override, $full_name, $web_access, $password, $env) = split ':', $value;

    $self->{max_sessions} = $max_sessions;
    $self->{printer}      = $printer;
    $self->{override}     = $override;
    $self->{full_name}    = $full_name;
    $self->{web_access}   = $web_access;
    $self->{password}     = $password;
    my @envs = ();
    @envs = split '#', $env if $env;
    $self->{env}          = \@envs;
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

