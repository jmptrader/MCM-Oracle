package Mx::Sybase::ResultSet;

use strict;

use Text::CSV_XS;

use constant CSV_SEPARATOR => ',';
use constant CSV_EOL       => "\n";

#
# @columns    names of all the columns
# @rows       array containing all the rows with all the values
# size        total number of rows
# cursor      current position in the set
#

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    $self->{logger}  = $args{logger};

    $self->{size}    = undef;
    $self->{cursor}  = undef;
    $self->{rows}    = undef; 
    $self->{columns} = undef; 
    $self->{sth}     = undef; 

    bless $self, $class;

    if ( my $values_ref = $args{values} ) {
        if ( ref( $values_ref ) eq 'ARRAY' ) {
            $self->{rows}   = $values_ref;
            $self->{size}   = @{ $values_ref };
            $self->{cursor} = 1 if $self->{size} > 0;
        }
    }
    elsif ( my $sth = $args{sth} ) {
            $self->{sth} = $sth;
    }

    if ( my $columns_ref = $args{columns} ) {
        if ( ref( $columns_ref ) eq 'ARRAY' ) {
            $self->{columns} = $columns_ref;
        }
    }

    return $self;
}

#--------#
sub size {
#--------#
    my ( $self ) = @_;


    if ( $self->{sth} ) {
        $self->{logger}->logdie("method 'size' not allowed with delayed query");
    }

    return $self->{size};
}

#-----------#
sub columns {
#-----------#
    my ( $self ) = @_;


    return @{ $self->{columns} };
}

#-----------#
sub is_next {
#-----------#
    my ( $self ) = @_;


    if ( $self->{sth} ) {
        $self->{logger}->logdie("method 'is_next' not allowed with delayed query");
    }

    return $self->{cursor} < $self->{size};
}

#--------#
sub next {
#--------#
    my ( $self ) = @_;


    if ( my $sth = $self->{sth} ) {
        return $sth->fetchrow_array;
    }
    else {
        return if $self->{cursor} > $self->{size};

        my $index = $self->{cursor} - 1;

        $self->{cursor}++;

        my $row_ref = $self->{rows}->[$index];

        if ( ref( $row_ref ) eq 'ARRAY' ) {
            return @{ $row_ref };
        }

        return;
    }
}

#----------------#
sub next_preview {
#----------------#
    my ( $self ) = @_;


    if ( my $sth = $self->{sth} ) {
        $self->{logger}->logdie("method 'next_preview' not allowed with delayed query");
    }
    else {
        return if $self->{cursor} > $self->{size};

        my $index = $self->{cursor} - 1;

        my $row_ref = $self->{rows}->[$index];

        if ( ref( $row_ref ) eq 'ARRAY' ) {
            return @{ $row_ref };
        }

        return;
    }
}

#-------------#
sub next_hash {
#-------------#
    my ( $self ) = @_;


    my %hash = ();

    return unless my @values = $self->next();

    my @columns = @{ $self->{columns} };

    @hash{ @columns } = @values;

    return %hash; 
}

#---------#
sub first {
#---------#
    my ( $self ) = @_;


    if ( $self->{sth} ) {
        $self->{logger}->logdie("method 'first' not allowed with delayed query");
    }

    $self->{cursor} = ( $self->{size} > 0 ) ? 1 : 0;
}

#--------#
sub last {
#---------#
    my ( $self ) = @_;


    if ( $self->{sth} ) {
        $self->{logger}->logdie("method 'last' not allowed with delayed query");
    }

    $self->{cursor} = $self->{size};
}

#------------#
sub all_rows {
#------------#
    my ( $self ) = @_;


    if ( $self->{sth} ) {
        $self->{logger}->logdie("method 'all_rows' not allowed with delayed query");
    }

    return unless $self->{size};
    return @{ $self->{rows} };
}

#
# Arguments:
#
# file:               full path to the csv file
# separator:          separator used in the csv file (optional, default is comma)
# quoted:             boolean indicating if all fields must be quoted (optional, default is false)
# no_quotes:          don't quote, not even if there are blanks
# no_columns:         boolean indicating if the column headers must be included (default is false)
# append:             boolean indicating if the file must be appended to or not
# ltrim, rtrim, trim, remove_blanks: self-explanatory
#
#----------#
sub to_csv {
#----------#
    my ($self, %args) = @_;

 
    my $logger = $self->{logger};

    $logger->debug('creating csv file ', $args{file});

    my $quoted     = $args{quoted}     || 0;
    my $no_columns = $args{no_columns} || 0; 
    my $quote_char = ( $args{no_quotes} ) ? undef : '"';
    my $separator  = ( exists $args{separator} ) ? $args{separator} : CSV_SEPARATOR;
    my $csv        = Text::CSV_XS->new( { binary => 1, always_quote => $quoted, sep_char => $separator, quote_space => 0, quote_char => $quote_char, escape_char => undef } );
    my $method     = $args{append} ? '>>' : '>';

    my $fh;
    unless ( $fh = IO::File->new( $args{file}, $method ) ) {
        $logger->error('cannot open csv file ', $args{file}, ": $!");
        return;
    }

    unless ( $no_columns ) {
        my @columns = $self->columns();
        if ( $csv->combine( @columns ) ) {
            print $fh $csv->string() . CSV_EOL;
        }
        else {
            $logger->error('csv combine failed: ' . $csv->error_input() );
        }
    }

    my $count = 0;
    while ( my @row = $self->next() ) {
        if ( $args{ltrim} or $args{trim} ) {
            _ltrim( @row );
        }
        if ( $args{rtrim} or $args{trim} ) {
            _rtrim( @row );
        }
        if ( $args{remove_blanks} ) {
            _remove_blanks( @row );
        }
        if ( $csv->combine( @row ) ) {
            my $string = $csv->string();
            $string =~ s/\n/ /g;
            print $fh $string . CSV_EOL;
            $count++;
        }
        else {
            $logger->error('csv combine failed: ' . $csv->error_input() );
        }
    }

    $fh->close();

    $logger->debug("csv file created, $count row(s) written");

    return 1;
}

#----------#
sub _rtrim {
#----------#
    map { $_ =~ s/\s+$// } @_;
}

#----------#
sub _ltrim {
#----------#
    map { $_ =~ s/^\s+// } @_;
}

#------------------#
sub _remove_blanks {
#------------------#
    map { $_ =~ s/\s+//g } @_;
}

1;
