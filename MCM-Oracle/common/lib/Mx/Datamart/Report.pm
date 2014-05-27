package Mx::Datamart::Report;

use strict;
no warnings 'experimental::smartmatch';

use v5.10;

use Mx::PerlScript;
use Mx::Scheduler;
use Mx::DBaudit;
use Mx::Sybase::ResultSet;
use IO::File;
use File::Copy;
use Carp;

use Data::Dumper;

#
#
# Properties:
#
# $id
# $label
# $type
# $location
# @columns
#
# $name
# $directory
#
# $starttime
# $endtime
# $size
# $nr_records
# $script_id
#
# $project
# $entity
# $runtype
#
# $status
# $fh
#
# for type CSV:
# $separator
# $quote_char
# @actions
# $header_included
# $sequence_field
#
# for type FIXED:
# $format
# @format_fields
# $format_length
# $header_included
#


our $TYPE_FIXED          = 'fixed';
our $TYPE_FIXED_TR       = 'fixed_tr';
our $TYPE_CSV            = 'csv';

our $LOCATION_TEMP       = 'temp';
our $LOCATION_DATA       = 'data';
our $LOCATION_TRANSFER   = 'transfer';
our $LOCATION_CDIRECT    = 'cdirect';
our $LOCATION_ENDUSER    = 'enduser';

our $STATUS_CLOSED       = 'closed';
our $STATUS_OPEN_READ    = 'open_read';
our $STATUS_OPEN_WRITE   = 'open_write';

our $MODE_READ           = 'read';
our $MODE_WRITE          = 'write';
our $MODE_APPEND         = 'append';

our $FIELD_STRING        = 'string';
our $FIELD_NUMBER        = 'number';
our $FIELD_MFDATE        = 'mfdate';
our $FIELD_SEQUENCE      = 'sequence';

my %QUOTE_CHARS = (
    single_quote => '\'',
    double_quote => '"'
);

my %SEPARATORS = (
    comma     => ',',
    colon     => ':',
    semicolon => ';',
    blank     => ' '
);

my %ACTIONS = (
    ltrim         => 'ltrim',
    rtrim         => 'rtrim',
    remove_blanks => 'remove_blanks',
    squash_zeroes => 'squash_zeroes',
    linefeeds     => 'linefeeds'
);


#
# Args:
#
# $label
# $name
# $location
# $script
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $script = $args{script} or croak 'missing argument in initialisation of report (script)';

    unless ( ref( $script ) eq 'Mx::PerlScript' ) {
        croak 'script argument is not a Mx::PerlScript object';
    }

    $self->{script_id} = $script->id;
   
    my $logger   = $self->{logger}   = $script->{logger};
    my $config   = $self->{config}   = $script->{config};
    my $db_audit = $self->{db_audit} = $script->{db_audit};
    my $project  = $self->{project}  = $script->{project};

    my $sched_js = $script->{sched_js};

    my $scheduler = Mx::Scheduler->new( jobstream => $sched_js, logger => $logger, config => $config );

    my $entity  = $self->{entity}  = $scheduler->entity();
    my $runtype = $self->{runtype} = $scheduler->runtype();

    my $label;
    unless ( $label = $self->{label} = $args{label} ) {
        $logger->logdie("missing argument in initialisation of report (label)");
    }

    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of report (name)");
    }

    my $location;
    unless ( $location = $self->{location} = $args{location} ) {
        $logger->logdie("missing argument in initialisation of report (location)");
    }

    my $directory;
    if ( $location eq $LOCATION_TEMP ) {
        $directory = $config->LCH_TMPDIR;
    }
    elsif ( $location eq $LOCATION_DATA ) {
        $directory = $config->LCH_DATADIR;
    }
    elsif ( $location eq $LOCATION_TRANSFER ) {
        $directory = $config->LCH_TRANSFERDIR;
    }
    elsif ( $location eq $LOCATION_CDIRECT ) {
        $directory = $config->LCH_CDDIR;
    }
    elsif ( $location eq $LOCATION_ENDUSER ) {
        $directory = $config->LCH_ENDUSERDIR;
    }
    else {
        $logger->logdie("wrong location specified in initialisation of report: $location");
    }

    $self->{directory} = $directory;

    _read_config( $self );

    $self->{size}       = 0;
    $self->{nr_records} = 0;
    $self->{starttime}  = time(); 
    $self->{status}     = $STATUS_CLOSED;
    $self->{fh}         = undef;

    $self->{id} = $db_audit->record_dm_report_start(
      label     => $self->{label},
      type      => $self->{type},
      script_id => $self->{script_id},
      name      => $self->{name},
      directory => $self->{directory},
      starttime => $self->{starttime},
      project   => $self->{project},
      entity    => $self->{entity},
      runtype   => $self->{runtype}
    );

    $logger->info("new report initialized (name: $name - location: $location - label: $label)");

    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $id;
    unless ( $id = $args{id} ) {
        $logger->logdie("missing argument in initialisation of report (id)");
    }
    $self->{id} = $id;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of report (config)");
    }
    $self->{config} = $config;

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of report (db_audit)");
    }
    $self->{db_audit} = $db_audit;

    my $row;
    unless ( $row = $db_audit->retrieve_dm_report( id => $id ) ) {
        $logger->logdie("no report found with id $id");
    }

    my (undef, $label, $type, $script_id, $name, $directory, $mode, $starttime, $endtime, $size, $nr_records, $project, $entity, $runtype, $business_date) = @{$row};

    $self->{label}         = $label;
    $self->{type}          = $type;
    $self->{script_id}     = $script_id;
    $self->{name}          = $name;
    $self->{directory}     = $directory;
    $self->{mode}          = $mode;
    $self->{starttime}     = $starttime;
    $self->{endtime}       = $endtime;
    $self->{size}          = $size;
    $self->{nr_records}    = $nr_records;
    $self->{project}       = $project;
    $self->{entity}        = $entity;
    $self->{runtype}       = $runtype;
    $self->{business_date} = $business_date;

    _read_config( $self );

    $self->{status} = $STATUS_CLOSED;
    $self->{fh}     = undef;

    bless $self, $class;
}

#----------------#
sub _read_config {
#----------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $label  = $self->{label};

    my $report_configfile = $config->retrieve('DM_REPORT_CONFIGFILE');
    my $report_config     = Mx::Config->new( $report_configfile );

    my $report_ref;
    unless ( $report_ref = $report_config->retrieve("DM_REPORTS.$label", 1) ) {
        $logger->logdie("report $label is not defined in the configuration file");
    }

    my $type = $self->{type} = $report_ref->{type};

    unless ( $type eq $TYPE_CSV or $type eq $TYPE_FIXED or $type eq $TYPE_FIXED_TR ) {
        $logger->logdie("wrong type specification in the configuration file ($type)");
    }

    my @columns = split ',', $report_ref->{columns};
    unless ( @columns ) {
        $logger->logdie("wrong columns specification in the configuration file");
    }

    _rtrim( \@columns );
    _ltrim( \@columns );

    $self->{columns} = [ @columns ];

    $self->{header_included} = ( $report_ref->{header_included} eq 'yes' ) ? 1 : 0;

    if ( $type eq $TYPE_CSV ) {
        my $separator;
        unless ( $separator = $report_ref->{separator} ) {
            $logger->logdie("missing separator specification in the configuration file");
        }

        unless ( exists $SEPARATORS{$separator} ) {
            $logger->logdie("wrong separator specification in the configuration file ($separator)");
        }

        $self->{separator_name} = $separator;
        $self->{separator}      = $SEPARATORS{$separator};

        if ( my $quote_char = $report_ref->{quote_char} ) {
            unless ( exists $QUOTE_CHARS{$quote_char} ) {
                $logger->logdie("wrong quote char specification in the configuration file ($quote_char)");
            }

            $self->{quote_char_name} = $quote_char;
            $self->{quote_char}      = $QUOTE_CHARS{$quote_char};
        }

        $self->{actions} = [];
        if ( my $actions = $report_ref->{actions} ) {
            my @actions = split ',', $actions;

            foreach my $action ( @actions ) {
                unless ( exists $ACTIONS{$action} ) {
                    $logger->logdie("wrong action specification in the configuration file ($action)");
                }

                push @{$self->{actions}}, $ACTIONS{$action};
            }
        }

        if ( my $sequence_field = $self->{sequence_field} = $report_ref->{sequence_field} ) {
            unless ( $sequence_field =~ /^\d+$/ ) {
                $logger->logdie("wrong sequence field specification in the configuration file ($sequence_field)");
            }
        }

        if ( my $format = $self->{format} = $report_ref->{format} ) {
            ( $self->{format_fields}, $self->{format_length}, $self->{sequence_field} ) = _decode_format( $format, $self->{columns}, $logger );
        }

        $self->{force_format} = ( $report_ref->{force_format} eq 'yes' ) ? 1 : 0;
    }
    elsif ( $type eq $TYPE_FIXED or $type eq $TYPE_FIXED_TR ) {
        my $format;
        unless ( $format = $report_ref->{format} ) {
            $logger->logdie("missing format specification in the configuration file");
        }
        $self->{format} = $format;

        ( $self->{format_fields}, $self->{format_length}, $self->{sequence_field} ) = _decode_format( $format, $self->{columns}, $logger );

        $self->{print_format} = $self->{format};
        $self->{print_format} =~ s/mfdate/u/g;
        $self->{print_format} =~ s/sequence/u/g;
    }
}

#
# Args:
#
# $mode
#
#--------#
sub open {
#--------# 
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};

    my $mode;
    unless ( $mode = $args{mode} ) {
        $logger->logdie("missing argument in open of report (mode)");
    }
    $self->{mode} = $mode;

    my $path = $self->{directory} . '/' . $self->{name};

    my $fh;
    if ( $mode eq $MODE_READ ) {
        unless ( $fh = IO::File->new( $path, '<' ) ) {
            $logger->logdie("cannot open $path for read: $!");
        }

        $self->{status}     = $STATUS_OPEN_READ;
        $self->{nr_records} = _nr_records( $path );
        $self->{fh}         = $fh;

        if ( $self->{header_included} ) {
          <$fh>;
          $self->{nr_records}--;
        }
    }
    elsif ( $mode eq $MODE_WRITE ) {
        unless ( $fh = IO::File->new( $path, '>' ) ) {
            $logger->logdie("cannot open $path for write: $!");
        }

        $self->{status}     = $STATUS_OPEN_WRITE;
        $self->{nr_records} = 0;
        $self->{fh}         = $fh;

        if ( $self->{header_included} ) {
          $self->add_record( fields => $self->{columns} );
          $self->{nr_records}--;
        }
    }
    elsif ( $mode eq $MODE_APPEND ) {
        unless ( $fh = IO::File->new( $path, '>>' ) ) {
            $logger->logdie("cannot open $path for append: $!");
        }

        $self->{status}     = $STATUS_OPEN_WRITE;
        $self->{nr_records} = _nr_records( $path );
        $self->{fh}         = $fh;

        if ( $self->{header_included} ) {
          $self->{nr_records}--;
        }
    }
    else {
        $logger->logdie("wrong argument in open of report ($mode)");
    }

    $self->{size} = -s $path;

    $db_audit->update_dm_report( id => $self->{id}, mode => $self->{mode}, size => $self->{size}, nr_records => $self->{nr_records} ); 

    $logger->debug("report $path opened for $mode (size: " . $self->{size} . " - nr_records: " . $self->{nr_records} . ")");

    return 1;
}

#
# Args:
# 
# $record of @fields or %fields
#
#--------------#
sub add_record {
#--------------#
    my ( $self, %args ) = @_;


    unless ( $self->{status} eq $STATUS_OPEN_WRITE ) {
        $self->{logger}->logdie("cannot add a record to a report not opened for write");
    }

    my $record = $args{record}; 
    unless ( $record ) {
        my $fields;
        unless ( $fields = $args{fields} ) {
            $self->{logger}->logdie("missing fields argument in add_record");
        }

        if ( ref($fields) eq 'ARRAY' ) {
        }
        elsif ( ref($fields) eq 'HASH' ) { 
            my @columns = @{ $self->{columns} };

            my @fields = @{$fields}{@columns};

            $fields = [ @fields ];
        } 
        else {
            $self->{logger}->logdie("fields argument in add_record is not a hash or an array");
        }

        if ( my $field_nr = $self->{sequence_field} ) {
            $fields->[ $field_nr - 1 ] = $self->{nr_records} + 1;
        }

        if ( $self->{type} eq $TYPE_FIXED ) {
            $record = $self->_record_fixed( $fields );
        }
        elsif ( $self->{type} eq $TYPE_FIXED_TR ) {
            $record = $self->_record_fixed_tr( $fields );
        }
        elsif ( $self->{type} eq $TYPE_CSV ) {
            $record = $self->_record_csv( $fields );
        }
    }

    if ( print { $self->{fh} } $record, "\n" ) {
        $self->{nr_records}++;
    }
    else {
        $self->{logger}->logdie("adding of record failed: $!");
    }

    return 1;
}

#---------------#
sub add_records {
#---------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $resultset;
    unless ( $resultset = $args{resultset} ) {
        $logger->logdie("missing argument in add_records (resultset)");
    }

    unless ( ref( $resultset ) eq 'Mx::Database::ResultSet' ) {
        $logger->logdie("resultset argument is not a Mx::Database::ResultSet object");
    }

    while ( my @fields = $resultset->next ) {
        $self->add_record( fields => \@fields );
    }
}

#
# Args:
#
# $columns
#
#--------------#
sub get_record {
#--------------#
    my ( $self, %args ) = @_;


    unless ( $self->{status} eq $STATUS_OPEN_READ ) {
        $self->{logger}->logdie("cannot read a record from a report not opened for read");
    }

    my $fh = $self->{fh};

    my $record = <$fh>;

    unless ( $record ) {
        return;
    }

    chomp($record);

    if ( wantarray ) {
        my $fields_ref;
        if ( $self->{type} eq $TYPE_FIXED or $self->{type} eq $TYPE_FIXED_TR ) {
            $fields_ref = $self->_fields_fixed( $record );
        }
        elsif ( $self->{type} eq $TYPE_CSV ) {
            $fields_ref = $self->_fields_csv( $record );
        }

        if ( $args{columns} ) {
            my @columns = @{$self->{columns}};

            my %fields;
            @fields{@columns} = @{$fields_ref};

            return %fields;
        }

        return @{$fields_ref};
    }
    else {
        return $record;
    }
}

#
# Args
#
# $size
#
#---------------#
sub get_records {
#---------------#
    my ( $self, %args ) = @_;


    unless ( $self->{status} eq $STATUS_OPEN_READ ) {
        $self->{logger}->logdie("cannot read a record from a report not opened for read");
    }
 
    my $size = $args{size} || 0;
    my $fh   = $self->{fh};
    my $type = $self->{type};

    my @records = (); my $count = 0;
    while ( my $record = <$fh> ) { 
        chomp($record);

        my $fields_ref;
        if ( $type eq $TYPE_FIXED or $type eq $TYPE_FIXED_TR ) {
            $fields_ref = $self->_fields_fixed( $record );
        }
        elsif ( $type eq $TYPE_CSV ) {
            $fields_ref = $self->_fields_csv( $record );
        }

        push @records, $fields_ref;

        $count++;

        if ( $count == $size ) {
            return @records;
        }
    }

    return @records;
}

#---------------#
sub _record_csv {
#---------------#
    if ( $_[0]->{force_format} ) {
        for ( my $i = 0; $i < @{$_[1]}; $i++ ) {
            $_[1]->[$i] = sprintf $_[0]->{format_fields}->[$i]->{format}, $_[1]->[$i];
        }
    }

    my $linefeed = '';
    foreach my $action ( @{$_[0]->{actions}} ) {
        given( $action ) {
          when ( 'ltrim' )         { _ltrim( $_[1] ); break }
          when ( 'rtrim' )         { _rtrim( $_[1] ); break }
          when ( 'remove_blanks' ) { _remove_blanks( $_[1] ); break }
          when ( 'squash_zeroes' ) { _squash_zeroes( $_[1] ); break }
          when ( 'linefeeds' )     { $linefeed = "\r"; break }
        }
    }

    my $separator = $_[0]->{quote_char} . $_[0]->{separator} . $_[0]->{quote_char};

    $_[0]->{quote_char} . ( join $separator, @{$_[1]} ) . $_[0]->{quote_char} . $linefeed;
}

#---------------#
sub _fields_csv {
#---------------#
    my $separator = $_[0]->{separator};

    my @fields = split ( /$separator/, $_[1], -1 );

    if ( $_[0]->{quote_char} ) {
        foreach ( @fields ) { $_ = substr( $_, 1, -1 ) }
    }

    return \@fields;
}

#-----------------#
sub _record_fixed {
#-----------------#
    sprintf $_[0]->{print_format}, @{$_[1]};
}

#--------------------#
sub _record_fixed_tr {
#--------------------#
    my ( $self, $fields ) = @_;


    for ( my $i = 0; $i < @{$fields}; $i++ ) {
        my $format = $self->{format_fields}->[$i];
        if ( $format->{type} eq $FIELD_STRING && $format->{length} < length( $fields->[$i] ) ) {
            $fields->[$i] = substr( $fields->[$i], 0, $format->{length} );
        }
    }

    sprintf $self->{print_format}, @{$fields};
}

#-----------------#
sub _fields_fixed {
#-----------------#
    if ( length( $_[1] ) != $_[0]->{format_length} ) {
        my $record_length = length( $_[1] );
        my $format_length = $_[0]->{format_length};
        my $record        = $_[1];
        $_[0]->{logger}->logdie("cannot parse record because of incorrect length (record length: $record_length - format length: $format_length)\n$record");
    }

    my @fields = (); my $position = 0;
    foreach my $format_field ( @{$_[0]->{format_fields}} ) {
        my $field = substr( $_[1], $position, $format_field->{length} );

        if ( $format_field->{type} eq $FIELD_NUMBER ) {
            if ( $field =~ /^\s+$/ ) {
                $field = 0;
            }
            else {
                $field += 0;
            }
        }
        elsif ( $format_field->{type} eq $FIELD_MFDATE ) {
            if ( $field =~ /^[ 0]+$/ ) {
                $field = undef;
            }
            else {
                $field += 0;
            }
        }

        push @fields, $field;

        $position += $format_field->{length};
    }

    return \@fields;
}

#------------------#
sub _decode_format {
#------------------#
    my ( $format, $columns, $logger ) = @_;


    my @columns    = @{$columns};
    my $nr_columns = @columns;

    my @format_fields = (); my $format_length = 0; my $position = 0; my $sequence_field;
    while ( my ($flag, $width, $precision, $type) = $format =~ /\%([\+\- #0]?)(\d*)\.?(\d*)(\w+)/ ) {
        my $field_format = $&;
        $format = $';

        $width = $width || 0; # in case of a CSV format

        my $field_type = $FIELD_STRING;

        if ( $type =~ /^[idufg]$/i ) {
            $field_type = $FIELD_NUMBER;
        }
        elsif ( $type eq 'mfdate' ) {
            $field_type = $FIELD_MFDATE;
        }
        elsif ( $type eq 'sequence' ) {
            if ( $sequence_field ) {
                $logger->logdie("only one sequence field is supported");
            }

            $field_type = $FIELD_SEQUENCE;
            $sequence_field = $position + 1;
        }

        my $column_name = $columns[$position];

        push @format_fields, { name => $column_name, length => $width, type => $field_type, position => $position, format => $field_format };

        $format_length += $width;

        $position++;
    }

    if ( $position != $nr_columns ) {
        $logger->logdie("number of columns ($nr_columns) does not match the number of fields in the format string ($position)");
    }

    return ( \@format_fields, $format_length, $sequence_field );
}

#
# Args:
#
# $location
# optional: $name
#
#------------#
sub relocate {
#------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $db_audit  = $self->{db_audit};
    my $path      = $self->{directory} . '/' . $self->{name};

    unless ( $self->{status} eq $STATUS_CLOSED ) {
        $logger->logdie("only a closed report can be relocated");
    }

    my $location;
    unless ( $location = $args{location} ) {
        $logger->logdie("missing argument in relocate of report (location)");
    }

    my $directory;
    if ( $location eq $LOCATION_TEMP ) {
        $directory = $config->LCH_TMPDIR;
    }
    elsif ( $location eq $LOCATION_DATA ) {
        $directory = $config->LCH_DATADIR;
    }
    elsif ( $location eq $LOCATION_TRANSFER ) {
        $directory = $config->LCH_TRANSFERDIR;
    }
    elsif ( $location eq $LOCATION_CDIRECT ) {
        $directory = $config->LCH_CDDIR;
    }
    elsif ( $location eq $LOCATION_ENDUSER ) {
        $directory = $config->LCH_ENDUSERDIR;
    }
    else {
        $logger->logdie("wrong location specified in relocate of report: $location");
    }

    my $newpath = $directory . '/' . $self->{name};

    if ( File::Copy::copy $path, $newpath ) {
        unlink( $path );

        $self->{directory} = $directory;

        $db_audit->update_dm_report( id => $self->{id}, directory => $directory );

        $logger->debug("report $path relocated to $directory");
    }
    else {
        $logger->logdie("unable to relocate report $path to $directory: $!");
    }

    if ( $args{name} ) {
        return $self->rename( name => $args{name} );
    }

    return 1;
}

#
# Args:
#
# $name
#
#----------#
sub rename {
#----------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    my $path     = $self->{directory} . '/' . $self->{name};

    unless ( $self->{status} eq $STATUS_CLOSED ) {
        $logger->logdie("only a closed report can be renamed");
    }

    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("missing argument in rename of report (name)");
    }

    my $newpath = $self->{directory} . '/' . $name;

    if ( rename $path, $newpath ) {
        $self->{name} = $name;

        $db_audit->update_dm_report( id => $self->{id}, name => $name );

        $logger->debug("report $path renamed to $name");
    }
    else {
        $logger->logdie("unable to rename report $path to $name: $!");
    }

    return 1;
}

#----------------#
sub datamartcopy {
#----------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $path   = $self->{directory} . '/' . $self->{name};

    my $new_directory = $args{directory} || $self->{directory};
    my $new_name      = $args{name}      || $self->{name};
    my $new_path      = $new_directory . '/' . $new_name;

    if ( File::Copy::copy $path, $new_path ) {
        $logger->debug("report $path copied to $new_path");
    }
    else {
        $logger->logdie("unable to copy report $path to $new_path: $!");
    }

    return 1;
}

#----------#
sub append {
#----------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my $report;
    unless ( $report = $args{report} ) {
        $logger->logdie("missing argument in append of report (report)");
    }

    unless ( $self->open( mode => $MODE_APPEND ) ) {
        $logger->logdie("unable to append to target report");
    }
    
    unless ( $report->open( mode => $MODE_READ ) ) {
        $logger->logdie("unable to read from report to be appended");
    }

    while ( my $record = $report->get_record ) {
        $self->add_record( record => $record );
    }

    $self->finish;
    $report->finish;

    return 1;
}

#----------#
sub finish {
#----------#
    my ( $self ) = @_;


    my $logger   = $self->{logger};
    my $db_audit = $self->{db_audit};
    my $id       = $self->{id};
    my $fh       = $self->{fh};
    my $path     = $self->{directory} . '/' . $self->{name};

    $fh->close;

    $self->{fh}      = undef;
    $self->{status}  = $STATUS_CLOSED;
    $self->{size}    = -s $path;
    $self->{endtime} = time();

    $db_audit->record_dm_report_end(
      id         => $self->{id},
      endtime    => $self->{endtime},
      nr_records => $self->{nr_records},
      size       => $self->{size}
    );

    $logger->info("report $path closed");
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $path   = $self->{directory} . '/' . $self->{name};

    unless ( $self->{status} eq $STATUS_CLOSED ) {
        $logger->logdie("only a closed report can be deleted");
    }

    if ( unlink( $path ) ) {
        $logger->info("report $path deleted");
        return 1;
    }
    else {
        $logger->error("report $path cannot be deleted: $!");
        return;
    }
}

#----------#
sub exists {
#----------#
    my ( $self ) = @_;


    my $path   = $self->{directory} . '/' . $self->{name};
    
    if ( -f $path ) {
        return 1;
    }

    return;
}

#-----------#
sub columns {
#-----------#
    my ( $self ) = @_;


    return @{$self->{columns}};
}

#--------------#
sub db_columns {
#--------------#
    my ( $self ) = @_;


    return map { 'M_' . $_ } @{$self->{columns}};
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#-------------#
sub script_id {
#-------------#
    my ( $self ) = @_;

    return $self->{script_id};
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#-------------#
sub directory {
#-------------#
    my ( $self ) = @_;

    return $self->{directory};
}

#--------#
sub path {
#--------#
    my ( $self ) = @_;

    return $self->{directory} . '/' . $self->{name};
}

#---------#
sub label {
#---------#
    my ( $self ) = @_;

    return $self->{label};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;

    return $self->{type};
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

#-------------#
sub starttime {
#-------------#
    my ( $self ) = @_;

    return $self->{starttime};
}

#-----------#
sub endtime {
#-----------#
    my ( $self ) = @_;

    return $self->{endtime};
}

#-----------#
sub project {
#-----------#
    my ( $self ) = @_;

    return $self->{project};
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

#----------#
sub format {
#----------#
    my ( $self ) = @_;

    return $self->{format};
}

#-----------------#
sub format_fields {
#-----------------#
    my ( $self ) = @_;

    return $self->{format_fields} ? @{$self->{format_fields}} : ();
}

#-----------------#
sub format_length {
#-----------------#
    my ( $self ) = @_;

    return $self->{format_length};
}

#-------------#
sub separator {
#-------------#
    my ( $self ) = @_;

    return $self->{separator};
}

#------------------#
sub separator_name {
#------------------#
    my ( $self ) = @_;

    return $self->{separator_name};
}

#--------------#
sub quote_char {
#--------------#
    my ( $self ) = @_;

    return $self->{quote_char};
}

#-------------------#
sub quote_char_name {
#-------------------#
    my ( $self ) = @_;

    return $self->{quote_char_name};
}

#-----------#
sub actions {
#-----------#
    my ( $self ) = @_;

    return @{$self->{actions}};
}

#-------------------#
sub header_included {
#-------------------#
    my ( $self ) = @_;

    return $self->{header_included};
}

#--------#
sub mode {
#--------#
    my ( $self ) = @_;

    return $self->{mode};
}

#-----------------#
sub business_date {
#-----------------#
    my ( $self ) = @_;

    return $self->{business_date};
}

#---------------#
sub _nr_records {
#---------------#
    my ( $path ) = @_;


    my $nr_records = 0;

    CORE::open( FH, $path );
    $nr_records += tr/\n/\n/ while sysread( FH, $_, 4096 );
    close( FH );

    return $nr_records;
}

#----------#
sub _rtrim {
#----------#
    foreach ( @{$_[0]} ) { s/\s+$// };
}

#----------#
sub _ltrim {
#----------#
    foreach ( @{$_[0]} ) { s/^\s+// };
}

#------------------#
sub _remove_blanks {
#------------------#
    foreach ( @{$_[0]} ) { s/\s+//g };
}

#------------------#
sub _squash_zeroes {
#------------------#
    foreach ( @{$_[0]} ) { s/^0+[\.,]?0*$//g };
}


1;
