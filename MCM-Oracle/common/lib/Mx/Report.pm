package Mx::Report;

use strict;
use warnings;

use Carp;
use File::Copy;
use Fcntl ':flock';
use IO::File;
use File::Basename;
use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Util;
use Mx::Sybase;
use Mx::DBaudit;
use Mx::Semaphore;


#
# Attributes:
#
# id              unique id of the report
# session_id      id of the corresponding session that generated the report
# type            either 'file' or 'table'
# historize       if the table is historized or not
# status          see possible values below
# label           label of the report
# batchname       name of the Murex batch
# reportname      name of the Murex report
# entity          corresponding entity
# runtype         type (O, 1, X, V or N)
# mds             label of the marketdata set
# path            full path to the file in case of a 'file' type report
# final_path      path where the file must be moved to after generation
# tablename:      name of the table in case of a 'table' type report
# size:           size of the reportfile in bytes
# nr_records:     number of records in the file or table 
# starttime:      when the report was started
# endtime:        when the report ended
# archived:       boolean indicating if the report is archived
# compressed:     boolean indicating if the report is compressed
# filter
# logger:         a Mx::Log instance
# db_audit:       a Mx::DBaudit instance
# fh:             filehandle of a opened report of type 'file'
#

our $STATUS_INITIAL   = 1;
our $STATUS_GENERATED = 2;

#
# Used to instantiate a report
#
# Arguments:
#  id:           if the report already exists in the database, the id is supplied
#  type:         'file' or 'table'
#  historize
#  session_id
#  label
#  batchname
#  reportname
#  entity
#  runtype
#  mds
#  filter
#  logger:       a Mx::Log instance
#  db_audit:     a Mx::DBaudit instance
#
#-------#
sub new {
#-------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of table report (db_audit)");
    }
    $self->{db_audit} = $db_audit;

    my $type;
    if ( $type = $args{type} ) {
        unless ( $type eq 'file' or $type eq 'table' ) {
            $logger->logdie("wrong type specified ($type)");
        }
        $self->{type} = $type;
    }

    $self->{id}         = $args{id};
    $self->{session_id} = $args{session_id};
    $self->{label}      = $args{label};
    $self->{historize}  = $args{historize};
    $self->{batchname}  = $args{batchname};
    $self->{reportname} = $args{reportname};
    $self->{path}       = $args{path};
    $self->{final_path} = $args{final_path};
    $self->{entity}     = $args{entity};
    $self->{runtype}    = $args{runtype};
    $self->{mds}        = $args{mds};
    $self->{filter}     = $args{filter};
    $self->{archived}   = 0;
    $self->{compressed} = 0;
    $self->{fh}         = undef;

    $self->{status}     = $STATUS_INITIAL;

    bless $self, $class;
}

#-------------#
sub _retrieve {
#-------------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};

    my $id;
    unless ( $id = $self->{id} ) {
        $logger->logdie("cannot retrieve a report without id");
    }

    my $row;
    unless ( $row = $db_audit->retrieve_report( id => $id ) ) {
        $logger->error("no report found with id $id");
    }
    
    my (undef, $label, $type, $session_id, $batchname, $reportname, $entity, $runtype, $mds, $starttime, $endtime, $size, $nr_records, $tablename, $path, $business_date, $duration, $ab_session_id, $command, $exitcode, $cduration, $status, $archived, $compressed, $filter) = @{$row};

    $self->{label}      = $label;
    $self->{type}       = $type;
    $self->{session_id} = $session_id;
    $self->{batchname}  = $batchname;
    $self->{reportname} = $reportname;
    $self->{entity}     = $entity;
    $self->{runtype}    = $runtype;
    $self->{mds}        = $mds;
    $self->{starttime}  = $starttime;
    $self->{endtime}    = $endtime;
    $self->{size}       = $size;
    $self->{nr_records} = $nr_records;
    $self->{tablename}  = $tablename;
    $self->{path}       = $path;
    $self->{status}     = $status;
    $self->{archived}   = $archived;
    $self->{compressed} = $compressed;
    $self->{filter}     = $filter;
}

#------------#
sub retrieve {
#------------#
    my ( $what, %args ) = @_;


    if ( $what eq 'Mx::Report' ) {
        my %reports = ();

        my $logger = $args{logger} or croak 'no logger defined.';

        my $session_id;
        unless ( $session_id = $args{session_id} ) {
            $logger->logfail("missing argument (session_id)");
        }

        my $db_audit;
        unless ( $db_audit = $args{db_audit} ) {
            $logger->logfail("missing argument (db_audit)");
        }

        my @report_ids = $db_audit->retrieve_linked_reports( session_id => $session_id );

        foreach my $report_id ( @report_ids ) {
            my $report = Mx::Report->new( id => $report_id, db_audit => $db_audit, logger => $logger );
            $report->_retrieve();
            my $label = $report->{label};
            $reports{ $label } = $report;
        }

        return %reports;
    }
    elsif ( ref($what) eq 'Mx::Report' ) {
        $what->_retrieve();
    }
}

#---------#
sub start {
#---------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    my $label;
    unless ( $label = $self->{label} ) {
        $logger->logdie("cannot store a report without a label");
    }
    my $id;
    if ( my $id = $db_audit->record_report_start( label => $label, type => $self->{type}, session_id => $self->{session_id}, entity => $self->{entity}, runtype => $self->{runtype}, mds => $self->{mds}, batchname => $self->{batchname}, reportname => $self->{reportname}, path => $self->{path}, status => $self->{status}, filter => $self->{filter} ) ) {
        $self->{id} = $id;
        $logger->info("report with label '$label' has id $id");
        return $id;
    }
    return;
}

#--------#
sub open {
#--------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $path   = $self->{path};

    unless ( $self->{type} eq 'file' ) {
        $logger->logdie("can only open reports of type 'file'");
    }

    unless ( $path ) {
        $logger->logdie("can only open reports which have their path defined");
    }

    if ( $self->{fh} ) {
        $logger->error("report is already opened, close first");
        return 0;
    }

    my $mode;                                                                                                                                                                                             
    if ( $args{mode} eq 'read' ) {
        $mode = '<';
    }
    elsif ( $args{mode} eq 'write' ) {
        $mode = '>';
    }
    elsif ( $args{mode} eq 'append' ) {
        $mode = '>>';
    }
    else {
        $logger->logdie("wrong mode specified");
    }

    my $fh;
    if ( $fh = IO::File->new( $path, $mode ) ) {
        $self->{fh} = $fh;
    }
    else {
        $logger->error("cannot open report with as path $path: $!");
        return 0;
    } 

    $logger->info("report with path $path opened");

    return 1;
}

#---------#
sub close {
#---------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $path   = $self->{path};

    unless ( $self->{fh} ) {
        $logger->error("report is not opened");
        return 0;
    }

    $self->{fh}->close;
    $self->{fh} = undef;

    $logger->info("report with path $path closed");

    return 1;
}

#-----------#
sub cleanup {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( $self->{type} eq 'file' ) {
        my $path   = $self->{path};

        if ( unlink( $path ) ) {
            $logger->debug("$path removed");
            return 1;
        }
        else {
            $logger->warn("cannot remove $path: $!");
            return 0;
        }
    }
}

#--------------#
sub add_record {
#--------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $fh;
    unless ( $fh = $self->{fh} ) {
        $logger->error("report is not opened");
        return 0;
    }

    my $record = $args{record};

    unless ( print $fh $record ) {
        $logger->logdie("adding record failed: $!");
    }
}

#--------------#
sub get_record {
#--------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $fh;
    unless ( $fh = $self->{fh} ) {
        $logger->error("report is not opened");
        return 0;
    }

    <$fh>; 
}

#----------#
sub append {
#----------#
    my ( $self, $report ) = @_;


    $self->open( mode => 'append' );
    $report->open( mode => 'read' );

    while ( my $record = $report->get_record() ) {
        $self->add_record( record => $record );
    } 

    $self->close();
    $report->close();
}

#------------#
sub set_path {
#------------#
    my ( $self, $path ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    unless ( $path ) {
        $logger->logdie("no path specified");
    }
    $self->{path} = $path;
    $db_audit->update_report( path => $path, id => $self->{id} );
}

#------------------#
sub set_final_path {
#------------------#
    my ( $self, $path ) = @_;


    $self->{final_path} = $path;
}

#-----------------#
sub set_tablename {
#-----------------#
    my ( $self, $tablename ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    unless ( $tablename ) {
        $logger->logdie("no tablename specified");
    }
    $self->{tablename} = $tablename;
    $db_audit->update_report( tablename => $tablename, id => $self->{id} );
}

#----------#
sub finish {
#----------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};

    if ( $self->{type} eq 'file' ) {
        return unless defined _file_size( $self );
        _file_nr_records( $self );
    }
    elsif ( $self->{type} eq 'table' ) {
        return 1 unless $self->{historize};
        my $sybase;
        unless ( $sybase = $args{sybase} ) {
            $logger->logdie("missing argument (sybase)");
        } 
        return unless defined _table_nr_records( $self, $sybase );
    }

    $self->{status} = $STATUS_GENERATED;

    $db_audit->record_report_end( id => $self->{id}, nr_records => $self->{nr_records}, size => $self->{size}, status => $self->{status} );

    if ( $self->{final_path} ) {
        $self->make_copy( path => $self->{final_path}, erase => 1 );
    }

    return 1;
}


#
# Arguments:
#
# path:   full pathname of the copy
# erase:  boolean indicating that the orignal file must be deleted after the copy
#
#-------------#
sub make_copy {
#-------------#
    my ($self, %args) = @_;
 

    my $logger = $self->{logger};
    my $config = $self->{config};

    unless ( $self->{type} eq 'file' ) {
        $logger->logdie("can only copy reports of type 'file'");
    }

    my $targetfile;
    unless ( $targetfile = $args{path} ) {
        $logger->logdie("missing argument (path)");
    }
    unless ( substr($targetfile, 0, 1) eq '/' ) {
        $logger->logdie("targetfile ($targetfile) is not fully qualified");
    }

    my $sourcefile = $self->{path};
    unless ( $sourcefile && -f $sourcefile ) {
        $logger->logdie("file ($sourcefile) does not exist");

    }

    #
    # check if the destination directory exists
    #
    my $targetdir = dirname( $targetfile );
    unless ( -d $targetdir ) {
        Mx::Util->mkdir( directory => $targetdir, logger => $logger );
    }

    unless ( copy( $sourcefile, $targetfile ) ) {
        $logger->logdie("unable to copy $sourcefile to $targetfile: $!");
    }
    else {
        $logger->debug("copied $sourcefile to $targetfile");
        $self->set_path( $targetfile );
    }

    if ( $args{erase} ) {
        unless ( unlink( $sourcefile ) ) {
            $logger->warn("unable to remove $sourcefile: $!");
        } else {
            $logger->debug("$sourcefile removed");
        }
    }

    return 1;
}


#--------------#
sub _file_size {
#--------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $path   = $self->{path};

    return unless $path;

    if ( my $reportname = $self->{reportname} ) {
        #
        # the file will have an extension we don't know upfront
        #
        my $new_path;
        my $pattern = $path . '.???';
        ( $new_path ) = glob( $pattern );

        unless ( $new_path ) {
            $logger->error("file $path does not exist (report: $reportname)");
            return;
        }

        $self->set_path( $new_path );

        $self->{size} = -s $new_path;
    }
    else {
        unless ( -f $path ) {
            $logger->error("file $path does not exist");
            return;
        }

        $self->{size} = -s $path;
    }
}

#---------------------#
sub _table_nr_records {
#---------------------#
    my ( $self, $sybase ) = @_; 


    return unless $sybase;

    unless ( defined( $self->{nr_records} = $sybase->table_size_info( $self->{tablename} ) ) ) {
        $self->{logger}->error("table " . $self->{tablename} . " doesn't exist");
        return;
    }

    return $self->{nr_records};
}

#--------------------#
sub _file_nr_records {
#--------------------#
    my ($self) = @_;

 
    my $logger = $self->{logger};
    my $path   = $self->{path};

    return unless $path;

    my $nr_records = 0; my $fh;
    unless ( $fh = IO::File->new( $path, '<' ) ) {
        $logger->error("cannot open $path for reading: $!");
        return;
    }

    $nr_records++ while <$fh>;

    $fh->close();

    $self->{nr_records} = $nr_records;
}


#--------------#
sub nr_records {
#--------------#
    my ( $self ) = @_;

    return $self->{nr_records};
}

#--------#
sub size {
#--------#
    my ( $self ) = @_;

    return $self->{size};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;

    return $self->{type};
}

#---------#
sub label {
#---------#
    my ( $self ) = @_;

    return $self->{label};
}

#----------#
sub entity {
#----------#
    my ( $self ) = @_;

    return $self->{entity};
}

#-----------#
sub runtype {
#-----------#
    my ( $self ) = @_;

    return $self->{runtype};
}

#-------#
sub mds {
#-------#
    my ( $self ) = @_;

    return $self->{mds};
}

#----------#
sub filter {
#----------#
    my ( $self ) = @_;

    return $self->{filter};
}

#--------#
sub path {
#--------#
    my ( $self ) = @_;

    return $self->{path};
}

#------------#
sub filename {
#------------#
    my ( $self ) = @_;

    return basename( $self->{path} );
}

#-------------#
sub tablename {
#-------------#
    my ( $self ) = @_;

    return $self->{tablename};
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#-------------#
sub batchname {
#-------------#
    my ( $self ) = @_;

    return $self->{batchname};
}

#---------------#
sub check_delay {
#---------------#
    my ( $class, %args ) = @_;

    
    my $config    = $args{config};
    my $logger    = $args{logger};
    my $db_audit  = $args{db_audit};
    my $template  = $args{template};
    my $delay     = $config->retrieve('BATCH_DELAY');

    $logger->debug("checking batch delay via template $template (required delay: $delay seconds)");

    unless ( -f $template ) {
        $logger->logdie("template '$template' not found");
    }

    my $key = basename( $template );

    my $max_start_delay = $db_audit->get_max_start_delay( interval => 600 );

    $max_start_delay += 60; # extra safety margin

    if ( $max_start_delay > $delay ) { 
        $logger->warn("increasing batch delay to $max_start_delay seconds");
        $delay = $max_start_delay;
    }

    my $semaphore = Mx::Semaphore->new( key => $key, type => $Mx::Semaphore::TYPE_TIME, create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    $semaphore->release( delay => $delay );

    $logger->debug("delay is OK");

    return 1;
}

#--------------------#
sub check_delay_orig {
#--------------------#
    my ( $class, %args ) = @_;

    
    my $config   = $args{config};
    my $logger   = $args{logger};
    my $template = $args{template};
    my $delay    = $config->retrieve('BATCH_DELAY');

    $logger->debug("checking batch delay via template $template (required delay: $delay seconds)");

    unless ( -f $template ) {
        $logger->logdie("template '$template' not found");
    }

    my $semaphore = Mx::Semaphore->new( key => 'check_delay', create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    my $current_time  = time();
    my $template_time = (stat($template))[9];
    my $age           = $current_time - $template_time;

    $logger->debug("current time: $current_time  template time: $template_time");
    
    while ( $age < $delay ) {
        $semaphore->release();

        my $extra_sleep = $delay - $age + int(rand($delay/2));

        $logger->debug("too close, sleeping for $extra_sleep seconds");

        sleep( $extra_sleep ); 

        $semaphore->acquire();
        
        $current_time  = time();
        $template_time = (stat($template))[9];
        $age           = $current_time - $template_time;
    
        $logger->debug("current time: $current_time  template time: $template_time");
    }

    my ($mtime, $atime);
    $mtime = $atime = time();

    unless ( utime( $atime, $mtime, $template ) ) {
        $semaphore->release();
        $logger->logdie("cannot update mtime of $template: $!");
    }

    #
    # do a flock + dummy update to force mtime change iso utime because of NFS attribute caching
    #
    #my $fh;
    #unless ( $fh = IO::File->new( $template, '+<' ) ) {
    #    $semaphore->release();
    #    $logger->logdie("cannot update mtime of $template: $!");
    #}

    #flock $fh, LOCK_EX;

    #$fh->close;

    $semaphore->release();

    $logger->debug("delay is OK");

    return 1;
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

