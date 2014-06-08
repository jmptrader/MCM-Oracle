package Mx::Template;

use strict;
use warnings;

use Mx::Log;
use Template;
use Template::Context;
use Template::Constants qw( :debug );
use String::CRC::Cksum qw( cksum );
use Hash::Flatten;
use File::Basename;
use File::Path qw( make_path );
use Text::Diff;
use POSIX qw( strftime );
use File::Copy;
use Carp;

#
# Attributes:
#
# path
# type
# text_original
# text_processed
# checksum
#

our $TYPE_TEXT   = 'text';
our $TYPE_BINARY = 'binary';

our $DEFAULT_TAG = 1; 
our $AT_TAG      = 2;

my %tags = (
  $DEFAULT_TAG => { start => quotemeta('[%'), end => quotemeta('%]') },
  $AT_TAG      => { start => quotemeta('@'),  end => quotemeta('@')  },
);

our %EXEC_EXTENSIONS = (
  sh  => 1,
  ksh => 1,
  pl  => 1,
);


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    unless ( $self->{path} = $args{path} ) {
        $logger->logdie("missing argument in initialisation of Mx::Template (path)");
    }

    $self->{type} = ( -T $self->{path} ) ? $TYPE_TEXT : $TYPE_BINARY;

    my $tag_type = $args{tag_type} || $DEFAULT_TAG;

    unless ( exists $tags{$tag_type} ) {
        $logger->logdie("wrong argument in initialisation of Mx::Template (tag_type)");
    }

    $self->{start_tag} = $tags{$tag_type}->{start};
    $self->{end_tag}   = $tags{$tag_type}->{end};

    my $fh;
    unless ( $fh = IO::File->new( $self->{path}, 'r' ) ) {
        $logger->error("unable to open $self->{path}: $!");
        return;
    }

    if ( $self->{type} eq $TYPE_BINARY ) {
        $self->{checksum} = cksum( $fh );
        $fh->close();
    }
    elsif ( $self->{type} eq $TYPE_TEXT ) {
        $self->{text_original} = '';
        while ( <$fh> ) {
            $self->{text_original} .= $_;
        }
        $fh->close();
    }

    $logger->debug("template $self->{path} initialized");

    bless $self, $class;
}

#-------------#
sub variables {
#-------------#
    my ( $self ) = @_;


    my $context = Template::Context->new( TRACE_VARS => 1, START_TAG => $self->{start_tag}, END_TAG => $self->{end_tag} );

    my $compiled;
    unless ( $compiled  = $context->template( \$self->{text_original} ) ) {
        $self->{logger}->logdie("unable to compile template $self->{path}: $context->error");
    }

    my $variables = $compiled->variables;

    my $flatter = Hash::Flatten->new();

    my $hashref = $flatter->flatten( $variables );

    return keys %{$hashref};
}

#-----------#
sub process {
#-----------#
    my ( $self, %args ) = @_;


    return 1 if $self->{type} eq $TYPE_BINARY;

    my $logger = $self->{logger};

    my $params;
    unless ( $params = $args{params} ) {
        $logger->logdie("missing argument for template process (params)");
    }

    $logger->debug("processing template $self->{path}");

    foreach my $variable ( $self->variables ) {
        unless ( $params->check_key( $variable ) ) {
            $logger->error("unable to process template $self->{path}: variable $variable is not defined");
            return 0;
        }
        $logger->debug("$variable: " . $params->retrieve( $variable ));
    }

    my $tt = Template->new( ABSOLUTE => 1, EVAL_PERL => 1, DEBUG => DEBUG_UNDEF, START_TAG => $self->{start_tag}, END_TAG => $self->{end_tag} );

    $self->{text_processed} = '';
    unless ( $tt->process( \$self->{text_original}, $params->hash, \$self->{text_processed} ) ) {
        $logger->error("unable to process template $self->{path}: " . $tt->error);
        return 0;
    }

    $self->{checksum} = cksum( $self->{text_processed} );

    $logger->debug("template $self->{path} is processed");

    return 1;
}

#-----------#
sub compare {
#-----------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $target;
    unless ( $target = $args{target} ) {
        $logger->logdie("missing argument for template compare (target)");
    }
    $self->{target} = undef;

    my $output_ref;
    unless ( $output_ref = $args{output} ) {
        $logger->logdie("missing argument for template compare (output)");
    }
    ${$output_ref} = '';

    $logger->debug("comparing template $self->{path} to target $target");

    #
    # the target doesn't exist
    #
    my $fh;
    unless ( $fh = IO::File->new( $target ) ) {
        $logger->warn("unable to open $target: $!");
        my $targetdir = dirname( $target );
        $self->{targetdir} = $targetdir unless -d $targetdir;
        $self->{target} = $target;
        ${$output_ref} = "$self->{target} does not exist";
        return 0;
    }

    #
    # the template is a binary file -> only checksum comparison
    #
    if ( $self->{type} eq $TYPE_BINARY ) {
        my $target_checksum = cksum( $fh );
        $fh->close();

        if ( $self->{checksum} == $target_checksum ) {
            $logger->info("binary template $self->{path} and target $target match");
            return 1;
        }
        else {
            $logger->info("binary template $self->{path} and target $target do not match");
            $self->{target} = $target;
            ${$output_ref} = "binary template $self->{path} ($self->{checksum}} and $target ($target_checksum) have different checkums";
            return 0;
        }
    }

    my $target_text = '';
    while ( <$fh> ) {
        $target_text .= $_;
    }
    $fh->close();

    my $target_checksum = cksum( $target_text );

    if ( $self->{checksum} == $target_checksum ) {
        $logger->info("template $self->{path} and target $target match");
        return 1;
    }

    $logger->info("template $self->{path} and target $target do not match");

    my $diff = diff( \$target_text, \$self->{text_processed}, { STYLE => 'Context', CONTEXT => 1 } );

    $logger->info($diff);

    $self->{target} = $target;

    ${$output_ref} = "template $self->{path} and $target differ:\n$diff";

    return 0;
}

#-----------#
sub install {
#-----------#
    my ( $self, %args ) = @_;


    my $target = $self->{target} || return 1; # comparison found no differences

    my $logger = $self->{logger};

    $logger->info("installing template $self->{path} to $target");

    if ( $self->{targetdir} ) {
        unless ( make_path( $self->{targetdir} ) ) {
            $logger->error("unable to create directory $self->{targetdir}: $!");
            return 0;
        }
    }

    #
    # make a backup
    #
    if ( -f $target && ! $args{no_backup} ) {
        my $timestamp = strftime( "%Y%m%d_%H%M%S", localtime() );

        my $renamed_target = $target . '_' . $timestamp;

        unless ( rename $target, $renamed_target ) {
            $logger->error("cannot rename $target to $renamed_target: $!");
            return 0;
        }
    }

    if ( $self->{type} eq $TYPE_TEXT ) {
        my $fh;
        unless ( $fh = IO::File->new( $target, '>' ) ) {
            $logger->error("cannot open $target for writing");
            return 0;
        }

        print $fh $self->{text_processed};

        $fh->close;

        $logger->info("template $self->{path} is installed to $target");

        my ( $extension ) = $target =~  /\.(\w+)$/;

        if ( $EXEC_EXTENSIONS{$extension} ) {
            my $perms = ( (stat($target))[2] & 07777 );

            $perms = $perms ^ 00111;

            unless ( chmod( $perms, $target ) ) {
                $logger->error("cannot make $target executable: $!");
                return 0;
            }

            $logger->info("$target made executable");
        }
    }
    else {
        unless ( copy( $self->{path}, $target ) ) {
            $logger->error("cannot copy $self->{path} to $target:$!");
            return 0;
        }

        $logger->info("binary template $self->{path} is installed to $target");
    }

    return 1;
}

1;
