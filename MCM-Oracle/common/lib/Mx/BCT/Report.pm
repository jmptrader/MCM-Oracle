package Mx::BCT::Report;

use strict;
no warnings 'experimental::smartmatch';

use v5.10;

use Mx::Datamart::Report;
use Tie::File;
use Fcntl 'O_RDONLY';
use List::Util qw( min );
use Carp;

our @ISA = qw(Mx::Datamart::Report);

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = $class->SUPER::new( %args );

    return $self;
}

#--------#
sub open {
#--------#
    my ( $self, %args ) = @_;


    $self->{error_message} = '';

    my $logger = $self->{logger};

    my $path = $self->{directory} . '/' . $self->{name};

    unless ( -f $path ) {
        $self->{error_message} = "cannot find report $path";
        $logger->error( $self->{error_message} );
        return;
    }

    my @records;

    tie @records, 'Tie::File', $path, mode => O_RDONLY;

    $self->{records}           = \@records;
    $self->{processed_records} = undef;

    $self->{status} = $Mx::Datamart::Report::STATUS_OPEN_READ;

    return $self->{nr_records};
}

#---------------#
sub get_records {
#---------------#
    my ( $self, %args ) = @_;


    unless ( $self->{status} eq $Mx::Datamart::Report::STATUS_OPEN_READ ) {
        $self->{logger}->logdie("cannot read a record from a report not opened for read");
    }

    my $start            = $args{start};
    my $length           = $args{length};
    my $values_index     = $args{values_index};
    my $excluded_columns = $args{excluded_columns};
    my $filter_columns   = $args{filter_columns};
    my $sort_columns     = $args{sort_columns};

    my $type             = $self->{type};
    my $records          = $self->{records};

    #
    # filter sub
    #
    my $filter_sub; my %filter = ();
    if ( $filter_columns && @{$filter_columns} ) {
        foreach my $column ( @{$filter_columns} ) {
            $filter{ $column->{index} } = $column->{filter};
        }

        $filter_sub = sub {
            while ( my( $index, $filter ) = each %filter ) {
                unless ( $_[0]->[ $index ] =~ /$filter/ ) {
                    keys %filter;
                    return;
                }
            }
            return 1;
        };

        $self->{filter_columns} = $filter_columns;
    }

    #
    # sort sub
    #
    my $sort_sub; my %sort = ();
    if ( $sort_columns && @{$sort_columns} ) {
        foreach my $column ( @{$sort_columns} ) {
            my $index      = $column->{index};
            my $direction  = $column->{direction};
            my $field_type = $self->{format_fields}->[$index]->{type};

            my $order;
            SWITCH: {
              $field_type eq $Mx::Datamart::Report::FIELD_STRING && $direction eq 'asc' && do { $order = '+s'; last SWITCH; };
              $field_type eq $Mx::Datamart::Report::FIELD_STRING && $direction ne 'asc' && do { $order = '-s'; last SWITCH; };
              $field_type ne $Mx::Datamart::Report::FIELD_STRING && $direction eq 'asc' && do { $order = '+n'; last SWITCH; };
              $field_type ne $Mx::Datamart::Report::FIELD_STRING && $direction ne 'asc' && do { $order = '-n'; last SWITCH; };
            }

            $sort{ $index } = $order;
        }

        $sort_sub = sub {
            while ( my( $index, $order ) = each %sort ) {
                my $cmp;
                given ( $order ) {
                  when ( '+s' ) { $cmp = $a->[$index] cmp $b->[$index]; break }
                  when ( '+n' ) { $cmp = $a->[$index] <=> $b->[$index]; break }
                  when ( '-s' ) { $cmp = $b->[$index] cmp $a->[$index]; break }
                  default       { $cmp = $b->[$index] <=> $a->[$index] }
                };

                if ( $cmp ) {
                    keys %sort;
                    return $cmp;
                }
            }
            return 0;
        };

        $self->{sort_columns} = $sort_columns;
    }

    my $records_ref; my $complete = 0; my $real_start = 0; my $nr_records = 0; my %values = ();
    #
    # the report has been already filtered or sorted
    #
    if ( $self->{processed_records} ) {
        $complete = 1;
        $records_ref = $self->{processed_records};

        if ( $filter_sub ) {
            my @filtered_records = ();
            foreach ( @{$records_ref} ) {
                push @filtered_records, $_ if &$filter_sub( $_ );
            }
            $records_ref = $self->{processed_records} = \@filtered_records;
        }

        if ( $values_index ) {
            foreach ( @{$records_ref} ) {
                $values{ $_->[ $values_index ] }++;
            }
        }

        $nr_records = @{$records_ref};
    }
    #
    # we start from scratch
    #
    else {
        $complete = ( $sort_sub or $filter_sub or $values_index or $length == 0 ) ? 1 : 0;

        $real_start = ( $complete ) ? 0 : $start;
        my $end = $self->{nr_records};

        my $real_length = $length;
        $real_length = 0 if ( $sort_sub or $filter_sub );

        if ( $self->{header_included} ) {
            $real_start++;
            $end++;
        }

        my @records = (); $records_ref = \@records;
        for ( my $i = $real_start; $i < $end; $i++ ) {
            my $fields_ref;
            if ( $type eq $Mx::Datamart::Report::TYPE_FIXED ) {
                $fields_ref = $self->_fields_fixed( $records->[$i] );
            }
            elsif ( $type eq $Mx::Datamart::Report::TYPE_CSV ) {
                $fields_ref = $self->_fields_csv( $records->[$i] );
            }

            my $record_nr = ( $self->{header_included} ) ? $i : $i + 1;

            unshift @{$fields_ref}, $record_nr;

            if ( $filter_sub ) {
                next unless &$filter_sub( $fields_ref );
            }

            if ( $values_index ) {
                $values{ $fields_ref->[ $values_index ] }++;
            }

            push @records, $fields_ref;

            last if ++$nr_records == $real_length;
        }

        $nr_records = $self->{nr_records} if $real_length != 0;

        $records_ref = \@records;
    }

    #
    # exclude specified columns
    #
    if ( $excluded_columns && @{$excluded_columns} ) {
        foreach ( @{$records_ref} ) {
            @$_[ @{$excluded_columns} ] = ( undef ) x @{$excluded_columns};
        }

        $self->{excluded_columns} = $excluded_columns;
    }

    #
    # do the sorting
    #
    if ( $sort_sub ) {
        my @sorted_records = sort { &$sort_sub } @{$records_ref};
        $records_ref = \@sorted_records;
    }

    $self->{processed_records} = $records_ref if $complete;

    if ( $values_index ) {
        return \%values;
    }

    #
    # determine the subset of rows to return
    #
        my $result_records;
    if ( $start >= $nr_records ) {
        $result_records = [];
    }
    elsif ( $complete && $length ) {
        my $end = $start + $length;
        $end = min( $nr_records -1 , $end );
        $result_records = [ @$records_ref[$start..$end] ];
    }
    else {
        $result_records = $records_ref;
    }

    return ( $result_records, $nr_records );
}

#---------#
sub store {
#---------#
    my ( $self, %args  ) = @_;


    $self->{error_message} = '';

    my $logger  = $self->{logger};
    my $config  = $self->{config};

    my $records;
    unless ( $records = $self->{processed_records} ) {
        $self->{error_message} = "unable to store an unprocessed report";
        $logger->error( $self->{error_message} );
        return;
    }

    my $win_user       = $args{win_user};
    my $name           = $args{name};
    my $comment        = $args{comment};
    my $process_id     = $args{process_id};
    my $process_name   = $args{process_name};
    my $max_nr_records = $args{max_nr_records} || 0;

    my $environment  = $ENV{MXENV};
    my $dm_report_id = $self->id;
    my $nr_columns   = $self->columns;
    my $separator    = $args{separator} || $self->separator || ';';
    my $timestamp    = time();

    my $excluded_columns = $self->{excluded_columns};
    my $filter_columns   = $self->{filter_columns};
    my $sort_columns     = $self->{sort_columns};

    my $directory = '/data/bct/reports';

    unless ( -d $directory ) {
        $self->{error_message} = "target directory $directory not found";
        $logger->error( $self->{error_message} );
        return;
    }

    my $db_bct;
    unless ( $db_bct = $config->retrieve( 'DB_BCT', 1 ) ) {
        $self->{error_message} = "BCT database is not defined";
        $logger->error( $self->{error_message} );
        return;
    }

    my $db_audit = Mx::DBaudit->new( database => $db_bct, config => $config, logger => $logger );

    my $bct_id = $db_audit->record_bct_report(
      dm_report_id     => $dm_report_id,
      environment      => $environment,
      name             => $name,
      directory        => $directory,
      nr_columns       => $nr_columns,
      separator        => $separator, 
      timestamp        => $timestamp,
      win_user         => $win_user,
      comment          => $comment,
      excluded_columns => $excluded_columns,
      filter_columns   => $filter_columns,
      sort_columns     => $sort_columns,
      process_id       => $process_id,
      process_name     => $process_name,
      report_label     => $self->{label}
    );

    my $outputfile = $directory . '/' . $bct_id;

    my $fh;
    unless ( $fh = IO::File->new( $outputfile, '>' ) ) {
        $self->{error_message} = "unable to open $outputfile: $!";
        $logger->error( $self->{error_message} );
        return;
    }

    my $bct_nr_records = 0;
    foreach ( @{$records} ) {
        my $line = join $separator, @{$_};
        unless ( print $fh "$line\n" ) {
            $self->{error_message} = "unable to write to $outputfile: $!";
            $logger->error( $self->{error_message} );
            return;
        }
        $bct_nr_records++;

        last if ( $max_nr_records > 0 && $bct_nr_records >= $max_nr_records );
    }

    $fh->close();

    my $bct_size = -s $outputfile;

    $db_audit->update_bct_report( id => $bct_id, size => $bct_size, nr_records => $bct_nr_records );

    $db_audit->close();

    $self->{bct_id}         = $bct_id;
    $self->{bct_size}       = $bct_size;
    $self->{bct_nr_records} = $bct_nr_records;

    return $bct_id;
}

#----------#
sub bct_id {
#----------#
    my ( $self ) = @_;

    return $self->{bct_id};
}

#------------#
sub bct_size {
#------------#
    my ( $self ) = @_;

    return $self->{bct_size};
}

#------------------#
sub bct_nr_records {
#------------------#
    my ( $self ) = @_;

    return $self->{bct_nr_records};
}

#-----------------#
sub error_message {
#-----------------#
    my ( $self ) = @_;

    return $self->{error_message};
}

1;
