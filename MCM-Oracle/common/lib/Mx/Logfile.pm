package Mx::Logfile;

use strict;
use warnings;

use Carp;
use File::stat;
use Fcntl qw( :seek );

use Mx::Mail;
use Mx::Process;

use constant EXTRACT_SIZE => 2000;

#
# Atttributes:
#
# $label
# $path
# $mtime
# $size
# $last_check_time
# $last_occurrence
# $curr_pos
# @fail_patterns
# $fail_addresses
# $fail_action
# @warn_patterns
# $warn_addresses
# $warn_action
# @timeout_patterns
# $timeout
# $timeout_flag
# $timeout_addresses
# $timeout_action
# $timeout_trigger
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    
    my $config;
    unless ( $config = $args{config} ) { 
        $logger->logdie("missing argument in initialisation of Logfile object (config)");
    }
    $self->{config} = $config;

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) { 
        $logger->logdie("missing argument in initialisation of Logfile object (db_audit)");
    }
    $self->{db_audit} = $db_audit;

    my $label;
    unless ( $label = $args{label} ) { 
        $logger->logdie("missing argument in initialisation of Logfile object (label)");
    }
    $self->{label} = $label;

    my $path;
    unless ( $path = $args{path} ) { 
        $logger->logdie("missing argument in initialisation of Logfile object (path)");
    }
    $self->{path} = $path;

    unless ( open( FH, "< $path" ) ) {
        $logger->error("cannot open $path: $!");
        return;
    } 

    seek( FH, 0, SEEK_END );

    $self->{curr_pos} = tell( FH );

    close(FH);

    _update_stats( $self );

    if ( my $fail_patterns = $config->retrieve("LOGFILES.$label.fail_pattern") ) {
        $self->{fail_patterns}     = ( ref( $fail_patterns ) eq 'ARRAY' ) ? $fail_patterns : [ $fail_patterns ];
        $self->{fail_addresses}    = $config->retrieve("LOGFILES.$label.fail_addresses");
        $self->{fail_action}       = $config->retrieve("LOGFILES.$label.fail_action");
    }

    if ( my $warn_patterns = $config->retrieve("LOGFILES.$label.warn_pattern") ) {
        $self->{warn_patterns}     = ( ref( $warn_patterns ) eq 'ARRAY' ) ? $warn_patterns : [ $warn_patterns ];
        $self->{warn_addresses}    = $config->retrieve("LOGFILES.$label.warn_addresses");
        $self->{warn_action}       = $config->retrieve("LOGFILES.$label.warn_action");
    }

    if ( my $timeout_patterns = $config->retrieve("LOGFILES.$label.timeout_pattern") ) {
        $self->{timeout}           = $config->retrieve("LOGFILES.$label.timeout");
        $self->{timeout_flag}      = $config->retrieve("LOGFILES.$label.timeout_flag");
        $self->{timeout_patterns}  = ( ref( $timeout_patterns ) eq 'ARRAY' ) ? $timeout_patterns : [ $timeout_patterns ];
        $self->{timeout_addresses} = $config->retrieve("LOGFILES.$label.timeout_addresses");
        $self->{timeout_action}    = $config->retrieve("LOGFILES.$label.timeout_action");
    }

    $self->{timeout_trigger}   = 0;
    $self->{last_occurrence}   = time(); 

    bless $self, $class;
    return $self;
}

#---------#
sub check {
#---------#
    my ( $self ) = @_;


    my $logger    = $self->{logger};
    my $old_mtime = $self->{mtime}; 
    my $old_size  = $self->{size}; 

    #
    # get the current size and modification time of the file
    #
    _update_stats( $self );

    if ( $self->{mtime} == $old_mtime ) {
        #
        # if the file has not been modified, check if a timeout <> 0 has been specified
        #
        if ( $self->{timeout} ) {
            return 0  if ( $self->{timeout_flag} && -f $self->{timeout_flag} );
            if ( $self->{last_check_time} - $self->{mtime} > $self->{timeout} ) {
                _take_action( $self, 'TIMEOUT' );
                return 1;
            }
        }
    }
    else {
        #
        # if the file has become smaller, set the reset variable
        #
        my $reset = ( $self->{size} < $old_size ) ? 1 : 0;
        #
        # get the piece of text which has been added to the file
        #
        my $text = _new_text( $self, $reset );
        #
        # check the fail patterns
        #
        foreach my $pattern ( @{$self->{fail_patterns}} ) {
            if ( my ( $extract, $start_pos, $length ) = _check_pattern( $self, $pattern, $text ) ) {
                _take_action( $self, 'FAIL', $extract, $start_pos, $length );
                return 1;
            }
        }
        #
        # check the warn patterns
        #
        foreach my $pattern ( @{$self->{warn_patterns}} ) {
            if ( my ( $extract, $start_pos, $length ) = _check_pattern( $self, $pattern, $text ) ) {
                _take_action( $self, 'WARN', $extract, $start_pos, $length );
                return 1;
            }
        }
        #
        # check the timeout patterns if there is a timeout specified
        #
        if ( $self->{timeout} ) {
            return 0  if ( $self->{timeout_flag} && -f $self->{timeout_flag} );
            foreach my $pattern ( @{$self->{timeout_patterns}} ) {
                if ( my ( $extract, $start_pos, $length ) = _check_pattern( $self, $pattern, $text ) ) {
                    $self->{last_occurrence} = time();
                    last;
                }
            }
            if ( @{$self->{timeout_patterns}} && ( $self->{last_check_time} - $self->{last_occurrence} > $self->{timeout} ) ) {
                _take_action( $self, 'TIMEOUT' );
                return 1;
            }
            #
            # the file has been modified, so reset the timeout trigger
            #
            $self->{timeout_trigger} = 0;
        }
    }

    return 0; 
}

#-----------------#
sub get_filenames {
#-----------------#
    my ( $class, %args ) = @_;


    my @list = ();
    my $logger = $args{logger} or croak 'no logger defined.';
    
    my $config;
    unless ( $config = $args{config} ) { 
        $logger->logdie("missing argument in class function call get_filenames (config)");
    }

    my $label;
    unless ( $label = $args{label} ) { 
        $logger->logdie("missing argument in class function call get_filenames (label)");
    }

    my $filename = $config->retrieve("LOGFILES.$label.filename");
    my @filenames = ( ref( $filename ) eq 'ARRAY' ) ? @{$filename} : ( $filename );
    my $root_dir = $config->MXENV_ROOT;

    foreach my $entry ( @filenames ) {
        $entry = $root_dir . '/' . $entry unless substr( $entry, 0, 1) eq '/';
        push @list, glob($entry);
    }

    return @list;
}

#------------------#
sub _check_pattern {
#------------------#
    my ( $self, $pattern, $text ) = @_; 

    
    my $logger = $self->{logger};
    my $extract = '';
    if ( $text =~ /$pattern/m ) {
        my $match_pos    = index( $text, $& );
        my $match_length = length( $& );
        my $start_pos    = $match_pos - ( EXTRACT_SIZE / 2 );
        $start_pos = 0 if $start_pos < 0;
        $extract = substr( $text, $start_pos, EXTRACT_SIZE );
        return ( $extract, $match_pos, $match_length );
    }
    return;
}

#----------------#
sub _take_action {
#----------------#
    my ( $self, $type, $extract, $start_pos, $length ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $db_audit  = $self->{db_audit};
    my $filename  = $self->{path};
    my $timestamp = $self->{mtime};
    my $mxenv     = $config->MXENV;

    my $subject = "$mxenv: LOGFILE ALERT - $type";
    my $body;
    if ( $extract ) {
        $body = "Filename: $filename\n\nExtract:\n$extract\n\n";
    }
    else {
        $body = "Filename: $filename\n\n";
    }

    my $addresses; my $action;
    if ( $type eq 'FAIL' ) {
        $addresses = $self->{fail_addresses};
        $action    = $self->{fail_action};
    }
    elsif ( $type eq 'WARN' ) {
        $addresses = $self->{warn_addresses};
        $action    = $self->{warn_action};
    }
    elsif ( $type eq 'TIMEOUT' ) {
        return 0 if $self->{timeout_trigger}++;
        $addresses = $self->{timeout_addresses};
        $action    = $self->{timeout_action};
    }

    if ( $extract ) {
        $db_audit->record_logfile_extract( timestamp => $timestamp, filename => $filename, type => $type, extract => $extract, start_pos => $start_pos, length => $length );
    }
    else {
        $db_audit->record_logfile_extract( timestamp => $timestamp, filename => $filename, type => $type );
    }

    if ( $action ) {
        $body .= "Action: $action\n";
        if ( my $process = Mx::Process->background_run( command => $action, logger => $logger, config => $config ) ) {
            $body .= "Status: launched\n";
        }
        else {
            $body .= "Status: failed\n";
        }
    }

    if ( $addresses ) {
        if ( my $mail = Mx::Mail->new( from => 'Murex Log Collector', to => $addresses, subject => $subject, body => $body, logger => $logger, config => $config ) ) {
            $mail->send();
        }
    }
}

#-----------------#
sub _update_stats {
#-----------------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $filename = $self->{path};

    my $stat;
    unless ( $stat = stat( $filename ) ) {
        $logger->error("cannot stat $filename: $!");
        return 0;
    }

    $self->{mtime}           = $stat->mtime; 
    $self->{size}            = $stat->size; 
    $self->{last_check_time} = time();

    return 1;
}

#-------------#
sub _new_text {
#-------------#
    my ( $self, $reset ) = @_;


    my $text = '';
    my $logger   = $self->{logger};
    my $filename = $self->{path};

    unless ( open( FH, "< $filename" ) ) {
        $logger->error("cannot open $filename: $!");
        return;
    }

    my $last_position = ( $reset ) ? 0 : $self->{curr_pos};

    seek( FH, $last_position, SEEK_SET );

    my $buffer;
    while ( my $length = read( FH, $buffer, EXTRACT_SIZE ) ) { 
        $text .= $buffer;
    }

    $self->{curr_pos} = tell ( FH );

    close(FH);

    return $text;
}

1;
