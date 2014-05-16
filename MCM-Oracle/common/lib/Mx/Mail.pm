package Mx::Mail;

use strict;
use warnings;

use MIME::Lite;
use MIME::Types;
use Net::SMTPS;
use File::Basename;
use IO::File;
use Carp;

our $RETRY_INTERVAL = 5;
our $NR_RETRIES     = 3;

#
# Add MIME::Lite hack to support TLS authentication / encryption
#
*MIME::Lite::send_by_smtp_tls = sub {
    my( $self, $hostname, %args ) = @_;

    my $extract_addrs_ref =
      defined &MIME::Lite::extract_addrs
      ? \&MIME::Lite::extract_addrs
      : \&MIME::Lite::extract_full_addrs;

    my $hdr = $self->fields();
    my ( $from ) = $extract_addrs_ref->( $self->get('From') );
    my $to = $self->get('To');
    defined($to) or croak "send_by_smtp_tls: missing 'To:' address\n";
    my @to_all = $extract_addrs_ref->($to);

    if ( $MIME::Lite::AUTO_CC ) {
        foreach my $field ( qw( Cc Bcc ) ) {
            my $value = $self->get($field);
            push @to_all, $extract_addrs_ref->($value) if defined($value);
        }
    }

    my $user; my $password;
    if ( $user = $args{user} and $password = $args{password} ) {
        delete $args{user};
        delete $args{password};
    }

    my $port = $args{port} || 25;

    my $ssl = undef;
    if ( $port == 465 ) {
        $ssl = 'ssl';
    }
    elsif ( $port == 587 ) {
        $ssl = 'starttls';
    }

    my $smtp = MIME::Lite::SMTPS->new( $hostname, %args, doSSL => $ssl ) or croak "Failed to connect to mail server: $!\n";

    if ( $user && $password ) {
        $smtp->auth( $user, $password );
    }

    $smtp->mail( $from );
    $smtp->to( @to_all );
    $smtp->data();
    $self->print_for_smtp( $smtp );
    $smtp->dataend();

    1;
};

@MIME::Lite::SMTPS::ISA = qw( Net::SMTPS );

sub MIME::Lite::SMTPS::print { shift->datasend(@_) }

#
# Build a mail message (which is really a wrapper around a MIME::Lite object), without sending it.
# To send in html format send a html flag in the args ( html => 1 ).
# The to argument can be a string containing comma's (for multiple addresses) or a array reference.
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $args{logger} or croak 'no logger defined.';
    $self->{logger} = $logger;

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument in initialisation of Mail (config)');
    }
    $self->{config} = $config;

    my @required_args = qw(to subject);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument in initialisation of mail message ($arg)");
        }
    }

    my $mail_configfile = $config->retrieve('MAIL_CONFIGFILE');
    my $mail_config     = Mx::Config->new( $mail_configfile );

    foreach my $item ( 'to', 'cc', 'bcc' ) {
        if ( my $value = $args{$item} ) {
            my @list;
            if ( ref( $value ) eq 'ARRAY' ) {
                @list = @{$value};
            }
            else {
                @list = split ',', $value;
            }

            my @list2 = ();
            foreach my $address ( @list ) {
                if ( $address =~ /@/ ) {
                    push @list2, $address;
                }
                else {
                    my $address_ref = $mail_config->retrieve( "%MAIL%GROUPS%$address%address", 1 );
                    if ( $address_ref ) {
                        if ( ref($address_ref) eq 'ARRAY' ) {
                            push @list2, @{$address_ref};
                        }
                        else {
                            push @list2, $address_ref;
                        }
                    }
                    else {
                        $logger->error("mail group '$address' is not defined in $mail_configfile");
                    }
                }
            }

            $args{$item} = ( @list2 ) ? join ',', @list2 : undef;
        }
    }
   
    $args{from} ||= $mail_config->retrieve( '%MAIL%DEFAULT_SENDER' );

    unless ( $args{to} ) {
        $args{to}      = $args{from};
        $args{subject} = "empty to list, mail cannot be send";
        $logger->error( $args{subject} );
    }

    #
    # We first build a simple plain text mail.
    #
    my $type = $args{html} ? 'alternative' : 'mixed';
    my $message = MIME::Lite->new(
        From    => $args{from},
        To      => $args{to},
        Cc      => $args{cc},
        Bcc     => $args{bcc},
        Subject => $args{subject},
        Type    => 'multipart/'.$type,
    );

    if ( $args{body} ) {
        my $mime_type = $args{html} ? 'text/html' : 'text';
        $message->attach(
            Type    => $mime_type,
            Data    => $args{body}
        );
    }

    #
    # If the argument 'file' is specified, it should contain a string (one file) or a reference to a list (multiple files).
    # Those files are to be attached to the mail.
    #
    if ( defined $args{file} ) {
        if ( ref( $args{file} ) ne 'ARRAY' ) {
            $args{file} = [ $args{file} ];
        }

        foreach my $file ( @{ $args{file} } ) {
            #
            # Check if the file can be opened for reading, otherwise skip it.
            #
            my $fh; 
            unless ( $fh = IO::File->new( $file, '<' ) ) {
                $logger->error("cannot locate mail attachment ($file)");
                next;
            }
            $fh->close();

            $message->attach(
                Type        => 'AUTO',
                Path        => $file,
                Filename    => basename($file),
                Disposition => 'attachment',
            );
        }
    }

    $logger->debug('new mail message initialized (from: ' . $args{from} . ' - to: ' . $args{to} . ')');

    bless { message => $message, logger => $logger, config => $config }, $class;
}

#
# Send the mail message.
#
#--------#
sub send {
#--------#
    my ($self) = @_;


    my $logger        = $self->{logger};
    my $smtp_relay    = $self->{config}->SMTP_RELAY;
    my $smtp_port     = $self->{config}->retrieve( 'SMTP_PORT', 1 ) || 25;
    my $smtp_user     = $self->{config}->retrieve( 'SMTP_USER', 1 ) || undef;
    my $smtp_password = $self->{config}->retrieve( 'SMTP_PASSWORD', 1 ) || undef;

    my $nr_retries = 0;

    while ( 1 ) {
        eval { $self->{message}->send_by_smtp_tls( $smtp_relay, port => $smtp_port, user => $smtp_user, password => $smtp_password ); };

        if ( $@ ) {
            $logger->error("mail message could not be sent: $@");

            $nr_retries++;

            if ( $nr_retries > $NR_RETRIES ) {
                $logger->error("giving up");
                return;
            }
            else {
                $logger->error("going for a retry in $RETRY_INTERVAL seconds");
                sleep $RETRY_INTERVAL;
            }
        }
        else {
            $self->{logger}->debug('mail message sent');
            return 1;
        }
    }
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
