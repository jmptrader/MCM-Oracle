package Mx::Datamart::Filter;

use strict;
use Carp;

use Mx::Murex;

#
# properties:
#
# batch_label
# filter_label
# filter_id
# dates
# mds
# portfolios
# products
# counterparties
# expression
# expression_epla
#
 
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;
 
 
    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (config)");
    }

    my $batch_configfile = $config->retrieve('DM_BATCH_CONFIGFILE');
    my $batch_config     = Mx::Config->new( $batch_configfile );

    my $oracle;
    unless ( $oracle = $self->{oracle} = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (oracle)");
    }

    my $library;
    unless ( $library = $self->{library} = $args{library} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (library)");
    }

    my $sql_library = Mx::SQLLibrary->new( file => $config->DM_BATCH_SQLFILE, logger => $logger );

    my $batch_label;
    unless ( $batch_label = $self->{batch_label} = $args{batch_label} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (batch_label)");
    }

    my $entity  = $args{entity}  || 'XX';
    my $runtype = $args{runtype} || 'N';

    my $batch_ref;
    unless ( $batch_ref = $batch_config->retrieve("%DM_BATCHES%$batch_label", 1) ) {
        $logger->info("batch '$batch_label' is not defined in the configuration file");
        return;
    }

    my $batch_name = $batch_ref->{name};

    my $query;
    unless ( $query = $library->query('get_batch_filter') ) {
        $logger->logdie("cannot retrieve query 'get_batch_filter' from the SQL library");
    }

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $batch_name ] ) ) {
        $logger->logdie("cannot retrieve filter for batch $batch_name");
    }

    my ($filter_id, $filter_label) = $result->next;

    $logger->info("filter of batch $batch_name identified; label:$filter_label id:$filter_id");

    $self->{filter_id}    = $filter_id;
    $self->{filter_label} = $filter_label;

    my $mds_label;
    if ( $runtype eq 'O' or $runtype eq '1' or $runtype eq 'V' or $runtype eq 'X' ) {
        $mds_label = 'mds-' . $runtype;
    }
    elsif ( $runtype eq 'N' ) {
        $mds_label = 'mds-O';
    }
    else {
        $logger->logdie("wrong runtype ($runtype) specified");
    }

    $mds_label = $batch_ref->{$mds_label} || $config->retrieve("%ENTITIES%$entity%$mds_label");

    unless ( $query = $library->query('mds_ref') ) {
        $logger->logdie("cannot retrieve query 'mds_ref' from the SQL library");
    }

    unless ( $result = $oracle->query( query => $query, values => [ $mds_label ] ) ) {
        $logger->logdie("cannot retrieve reference of MDS $mds_label");
    }

    my $mds_ref = $result->nextref->[0];

    my @dates      = ( 'default', 'default', 'today' );
    my @mds        = ( 'NULL', 'NULL', $mds_ref );
    my @mds_labels = ( '-', '-', $mds_label );

    my $is_correction_run = 0;
    if ( $runtype eq '1' or $runtype eq 'V' or $runtype eq 'X' ) {
        $is_correction_run = 1;
        $dates[2] = 'correction';
    } 

    for ( my $i = 0; $i <= 2; $i++ ) {
        if ( exists $batch_ref->{"date$i"} ) {
            my $value = $batch_ref->{"date$i"};
            if ( $value =~ /,/ ) {
                my @values = split /,/, $value;
                foreach ( @values ) {
                    if ( /^([O1VXC]):(.+)$/ ) {
                        if ( $1 eq $runtype or ( $1 eq 'C' && $is_correction_run ) ) {
                            $dates[$i] = $2;
                        }
                    }
                }
            }
            elsif ( $value =~ /^([O1VXC]):(.+)$/ ) {
                if ( $1 eq $runtype or ( $1 eq 'C' && $is_correction_run ) ) {
                    $dates[$i] = $2;
                }
            }
            elsif ( $value =~ /^\w+$/ ) {
                $dates[$i] = $value;
            }
        }

        if ( $dates[$i] ne 'default' ) {
            $mds[$i]        = $mds_ref;
            $mds_labels[$i] = $mds_label;
        }
    }

    my @portfolio_names = ();
    if ( exists $batch_ref->{portfolio} ) {
        if ( ref( $batch_ref->{portfolio} ) eq 'ARRAY' ) {
            @portfolio_names = @{$batch_ref->{portfolio}};
        }
        else {
            @portfolio_names = ( $batch_ref->{portfolio} );
        }
    }

    my @portfolios = ();
    foreach my $name ( @portfolio_names ) {
        if ( $name =~ /^\[(\w+)\]$/ ) {
            my $query;
            unless ( $query = $sql_library->query( $1 ) ) {
                $logger->logdie("cannot retrieve query '$1' from the SQL library");
            }

            if ( my $result = $oracle->query( query => $query ) ) {
                push @portfolios, map { $_->[0] } $result->all_rows;
            }
        }
        else {
            push @portfolios, $name;
        } 
    }

    my @counterparty_names = ();
    if ( exists $batch_ref->{counterparty} ) {
        if ( ref( $batch_ref->{counterparty} ) eq 'ARRAY' ) {
            @counterparty_names = @{$batch_ref->{counterparty}};
        }
        else {
            @counterparty_names = ( $batch_ref->{counterparty} );
        }
    }

    my @counterparties = ();
    foreach my $name ( @counterparty_names ) {
        if ( $name =~ /^\[(\w+)\]$/ ) {
            my $query;
            unless ( $query = $sql_library->query( $1 ) ) {
                $logger->logdie("cannot retrieve query '$1' from the SQL library");
            }

            if ( my $result = $oracle->query( query => $query ) ) {
                push @counterparties, map { $_->[0] } $result->all_rows;
            }
        }
        else {
            push @counterparties, $name;
        }
    }
    
    my @product_names;
    if ( exists $batch_ref->{product} ) {
        if ( ref( $batch_ref->{product} ) eq 'ARRAY' ) {
            @product_names = @{$batch_ref->{product}};
        }
        else {
            @product_names = ( $batch_ref->{product} );
        }
    }

    my @products = ();
    foreach my $product ( @product_names ) {
       push @products, _normalize_product( $self, $product );
    }
   
    my $expression;
    if ( exists $batch_ref->{expression} ) {
        my $expression_label;
        if ( ref( $batch_ref->{expression} ) eq 'ARRAY' ) {
            $logger->logdie("multiple expressions are not allowed in a filter ($batch_label)");
        }
        else {
            $expression_label = $batch_ref->{expression};
        }

        unless ( $expression = $sql_library->query( $expression_label ) ) {
            $logger->logdie("cannot retrieve query '$expression_label' from the DB_BATCH SQL library");
        }
    }

    my $expression_epla;
    if ( exists $batch_ref->{expression_epla} ) {
        my $expression_epla_label;
        if ( ref( $batch_ref->{expression_epla} ) eq 'ARRAY' ) {
            $logger->logdie("multiple expressions are not allowed in a filter ($batch_label)");
        }
        else {
            $expression_epla_label = $batch_ref->{expression_epla};
        }

        unless ( $expression_epla = $sql_library->query( $expression_epla_label ) ) {
            $logger->logdie("cannot retrieve query '$expression_epla_label' from the DB_BATCH SQL library");
        }
    }

    my @intvars = ();
    if ( exists $batch_ref->{intvar} ) {
        if ( ref( $batch_ref->{intvar} ) eq 'ARRAY' ) {
            @intvars = @{$batch_ref->{intvar}};
        }
        else {
            @intvars = ( $batch_ref->{intvar} );
        }
    }

    @intvars = map { _decode_intvar( $self, $_, $entity, $runtype ) } @intvars;

    $self->{batch_name}      = $batch_name;
    $self->{dates}           = \@dates;
    $self->{mds}             = \@mds;
    $self->{mds_labels}      = \@mds_labels;
    $self->{products}        = \@products;
    $self->{portfolios}      = \@portfolios;
    $self->{counterparties}  = \@counterparties;
    $self->{expression}      = $expression;
    $self->{expression_epla} = $expression_epla;
    $self->{intvars}         = \@intvars;

    bless $self, $class;
}


#-----------#
sub install {
#-----------#
    my ( $self, %args ) = @_;


    my $logger       = $self->{logger} or return;
    my $config       = $self->{config};
    my $oracle       = $self->{oracle};
    my $library      = $self->{library};
    my $batch_label  = $self->{batch_label};
    my $batch_name   = $self->{batch_name};
    my $filter_label = $self->{filter_label};
    my $filter_id    = $self->{filter_id};

    my @mds             = @{ $self->{mds} };
    my @mds_labels      = @{ $self->{mds_labels} };
    my @dates           = @{ $self->{dates} };
    my @portfolios      = @{ $self->{portfolios} };
    my @products        = @{ $self->{products} };
    my @counterparties  = @{ $self->{counterparties} };
    my $expression      = $self->{expression};
    my $expression_epla = $self->{expression_epla};
    my @intvars         = @{ $self->{intvars} };

    my $semaphore;
    unless ( $semaphore = $args{semaphore} ) {
        $logger->logdie("missing argument in install (semaphore)");
    }

    #
    # DATE PART
    #

    my $statement;
    unless ( $statement = $library->query('delete_date_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'delete_date_filter' from the SQL library");
    }

    unless ( $oracle->do( statement => $statement, values => [ $filter_id ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot cleanup date part of filter $filter_label");
    }

    my $index = 0;
    foreach my $date ( @dates ) {
        my $mds = shift @mds;

        my $label;
        if ( $date eq 'default' or $date eq 'today' or $date eq 'reporting' or $date eq 'correction' ) {
            $label = $date;
        }
        elsif ( $date =~ /^\d{8}$/ ) {
            $label = 'userdefined';
        }
        else {
            $label = 'dateshifter';
        }

        my $statement_label = 'set_' . $label . '_date_filter';
    
        unless ( $statement = $library->query( $statement_label ) ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve query '$statement_label' from the SQL library");
        }

        my @values = ( $filter_id, $index );

        if ( $label eq 'userdefined' or $label eq 'dateshifter' ) {
            push @values, $date;
        }

        if ( $date ne 'default' ) {
            push @values, $mds;
        }

        unless ( $oracle->do( statement => $statement, values => \@values ) ) {
            $semaphore->release();
            $logger->logdie("cannot install filter $filter_label: insert of date$index failed");
        }

        if ( $date ne 'default' ) {
            $logger->debug("installing date$index filter: $date - mds:$mds");
        } 

        $index++;
    }

    #
    # PORTFOLIO & PRODUCT & COUNTERPARTY PART
    #

    unless ( $statement = $library->query('delete_portfolio_product_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'delete_portfolio_product_filter' from the SQL library");
    }

    unless ( $oracle->do( statement => $statement, values => [ $filter_id ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot cleanup portfolio & product part of filter $filter_label");
    }

    unless ( $statement = $library->query('set_portfolio_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'set_portfolio_filter' from the SQL library");
    }

    foreach my $portfolio ( @portfolios ) {
        unless ( $oracle->do( statement => $statement, values => [ $filter_id, $portfolio ] ) ) {
            $semaphore->release();
            $logger->logdie("cannot install filter $filter_label: insert of portfolio $portfolio failed");
        }
        $logger->debug("installing portfolio filter: $portfolio");
    }

    unless ( $statement = $library->query('set_product_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'set_product_filter' from the SQL library");
    }

    foreach my $product ( @products ) {
        unless ( $oracle->do( statement => $statement, values => [ $filter_id, $product ] ) ) {
            $semaphore->release();
            $logger->logdie("cannot install filter $filter_label: insert of product $product failed");
        }
        $logger->debug("installing product filter: $product");
    }

    unless ( $statement = $library->query('set_counterparty_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'set_counterparty_filter' from the SQL library");
    }

    foreach my $counterparty ( @counterparties ) {
        unless ( $oracle->do( statement => $statement, values => [ $filter_id, $counterparty ] ) ) {
            $semaphore->release();
            $logger->logdie("cannot install filter $filter_label: insert of counterparty $counterparty failed");
        }
        $logger->debug("installing counterparty filter: $counterparty");
    }

    #
    # EXPRESSION PART
    #

    unless ( $statement = $library->query('delete_expression_filter') ) {
        $semaphore->release();
        $logger->logdie("cannot retrieve query 'delete_expression_filter' from the SQL library");
    }

    unless ( $oracle->do( statement => $statement, values => [ $filter_id ] ) ) {
        $semaphore->release();
        $logger->logdie("cannot cleanup expression part of filter $filter_label");
    }

    if ( $expression ) {
        unless ( $statement = $library->query('set_expression_filter') ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve query 'set_expression_filter' from the SQL library");
        }

        $logger->debug("installing expression filter:");

        my $index = 0;
        while ( my $expression_part = substr( $expression, 0, 64, '' ) ) {
            unless ( $oracle->do( statement => $statement, values => [ $filter_id, $index, $expression_part ] ) ) {
                $semaphore->release();
                $logger->logdie("cannot install filter $filter_label: insert of expression failed");
            }

            $logger->debug( $expression_part );

            $index++;
        } 
    }

    if ( $expression_epla ) {
        unless ( $statement = $library->query('set_expression_epla_filter') ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve query 'set_expression_epla_filter' from the SQL library");
        }

        $logger->debug("installing expression_epla filter:");

        my $index = 0;
        while ( my $expression_part = substr( $expression_epla, 0, 64, '' ) ) {
            unless ( $oracle->do( statement => $statement, values => [ $filter_id, $index, $expression_part ] ) ) {
                $semaphore->release();
                $logger->logdie("cannot install filter $filter_label: insert of expression failed");
            }

            $logger->debug( $expression_part );

            $index++;
        } 
    }

    #
    # INTERACTIVE VARIABLE PART
    #
    if ( @intvars ) {
        my $query;
        unless ( $query = $library->query('get_intvars') ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve query 'get_intvars' from the SQL library");
        }

        my $result;
        unless ( $result = $oracle->query( query => $query, values => [ $batch_name ] ) ) {
            $semaphore->release();
            $logger->logdie("cannot retrieve interactive variables for batch $batch_name");
        }

        my %names = (); my $nr_names = 0;

		while ( my ($name, $m_ref) = $result->next ) {
            $names{$name} = $m_ref;
            $nr_names++;
        }
        
        my $nr_intvars = @intvars;

        unless ( $nr_intvars == $nr_names ) {
            $semaphore->release();
            $logger->logdie("mismatch between number of interactive variables in the configuration file ($nr_intvars) and in the database ($nr_names)");
        }

        foreach my $intvar ( @intvars ) {
            my ( $name, $type, $datetype, $value, $entity ) = @{$intvar};

            unless ( exists $names{$name} ) {
                $semaphore->release();
                $logger->logdie("interactive variable '$name' in the configuration file does not exist in the database");
            }

            my $m_ref = $names{$name};

            if ( $type eq 'C' ) {
                unless ( $statement = $library->query('set_string_intvar') ) {
                    $semaphore->release();
                    $logger->logdie("cannot retrieve query 'set_string_intvar' from the SQL library");
                }

                unless ( $oracle->do( statement => $statement, values => [ $value, $name, $m_ref ] ) ) {
                    $semaphore->release();
                    $logger->logdie("cannot install interactive variable '$name'");
                }

                $logger->debug("interactive variable '$name' of string type installed, value '$value'");
            }
            elsif ( $type eq 'N' ) {
                unless ( $statement = $library->query('set_numeric_intvar') ) {
                    $semaphore->release();
                    $logger->logdie("cannot retrieve query 'set_numeric_intvar' from the SQL library");
                }

                unless ( $oracle->do( statement => $statement, values => [ $value, $name, $m_ref ] ) ) {
                    $semaphore->release();
                    $logger->logdie("cannot install interactive variable '$name'");
                }

                $logger->debug("interactive variable '$name' of numeric type installed, value '$value'");
            }
            elsif ( $type eq 'D' ) {
                my $label = 'set_date_intvar_' . $datetype;
                unless ( $statement = $library->query( $label ) ) {
                    $semaphore->release();
                    $logger->logdie("cannot retrieve query '$label' from the SQL library");
                }

                if ( $datetype eq 'today' ) {
                    my $plcc = 'PLCC_' . $entity;
                    my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
                    my $mo_date = Mx::Murex->date( type => 'MO', label => $plcc, oracle => $oracle, library => $sql_library, config => $config, logger => $logger );

                    $value = substr( $mo_date, 6, 2 ) . '/' . substr( $mo_date, 4, 2 ) . '/' . substr( $mo_date, 2, 2 );

                    unless ( $oracle->do( statement => $statement, values => [ $value, $name, $m_ref ] ) ) {
                        $semaphore->release();
                        $logger->logdie("cannot install interactive variable '$name'");
                    }
                }
                elsif ( $datetype eq 'correction' ) {
                    unless ( $oracle->do( statement => $statement, values => [ $name, $m_ref ] ) ) {
                        $semaphore->release();
                        $logger->logdie("cannot install interactive variable '$name'");
                    }
                }
                elsif ( $datetype eq 'dateshifter' ) {
                    unless ( $oracle->do( statement => $statement, values => [ $value, $name, $m_ref ] ) ) {
                        $semaphore->release();
                        $logger->logdie("cannot install interactive variable '$name'");
                    }
                }
                elsif ( $datetype eq 'userdefined' ) {
                    my $new_value = substr( $value, 6, 2 ) . '/' . substr( $value, 4, 2 ) . '/' . substr( $value, 2, 2 );

                    unless ( $oracle->do( statement => $statement, values => [ $new_value, $value, $name, $m_ref ] ) ) {
                        $semaphore->release();
                        $logger->logdie("cannot install interactive variable '$name'");
                    }
                }

                $logger->debug("interactive variable '$name' of date type installed");
            }
        }
    }

    return 1;
}

#----------#
sub record {
#----------#
    my ( $self, %args ) = @_;


    my $logger         = $self->{logger};
    my $batch_name     = $self->{batch_name};
    my $dates          = $self->{dates};
    my $mds_labels     = $self->{mds_labels};
    my $products       = $self->{products};
    my $portfolios     = $self->{portfolios};
    my $counterparties = $self->{counterparties};
    my $expression     = $self->{expression};

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in recording of Murex filter (db_audit)");
    }

    my $session_id;
    unless ( $session_id = $args{session_id} ) {
        $logger->logdie("missing argument in recording of Murex filter (session_id)");
    }

    $db_audit->record_dm_filter( session_id => $session_id, batch_name => $batch_name, dates => $dates, mds => $mds_labels, products => $products, portfolios => $portfolios, counterparties => $counterparties, expression => $expression );
}

#----------------------#
sub _normalize_product {
#----------------------#
    my ( $self, $product ) = @_;


    my $logger = $self->{logger};

    my ( $family, $group, $type ) = split /\|/, $product;

    unless ( $family ) {
        $logger->logdie("no family specified for product '$product'");
    }

    if ( $type and ! $group ) {
        $logger->logdie("no group specified for product '$product'");
    }

    $family =~ s/^\s*(\S+)\s*$/$1/;
    $group  =~ s/^\s*(\S+)\s*$/$1/ if $group;
    $type   =~ s/^\s*(\S+)\s*$/$1/ if $type;

#    $product = sprintf "%-5s|%-5s|%-5s", $family, $group, $type;
    $product = sprintf "%s|%s|%s", $family, $group, $type;

    $logger->debug("normalized product is '$product'");

    return $product;
}

#------------------#
sub _decode_intvar {
#------------------#
    my ( $self, $intvar, $entity, $runtype ) = @_;


    my $logger = $self->{logger};

    my ( $name, $type, $value ) = split /:/, $intvar, 3;

    unless ( $name ) {
        $logger->logdie("no name specified for interactive variable ($intvar)");
    }

    unless ( $value ) {
        $logger->logdie("no value specified for interactive variable '$name'");
    }

    my $datetype;
    if ( $type eq 'C' ) {
        $value =~ s/__ENTITY__/$entity/g;
        $value =~ s/__RUNTYPE__/$runtype/g;

        $logger->debug("interactive variable '$name' of string type with as value '$value' specified");
    }
    elsif ( $type eq 'N' ) {
        unless ( $value =~ /^\d+$/ ) {
            $logger->logdie("invalid value specified for interactive variable '$name' of numeric type ($value)");
        }

        $logger->debug("interactive variable '$name' of numeric type with as value '$value' specified");
    }
    elsif ( $type eq 'D' ) {
        if ( $value eq 'today' ) {
             $datetype = 'today';
        }
        elsif ( $value eq 'correction' ) {
             $datetype = 'correction';
        }
        elsif ( $value eq 'runtype' ) {
            if ( $runtype eq '1' or $runtype eq 'V' or $runtype eq 'X' ) {
                $datetype = 'correction';
            }
            else {
                $datetype = 'today';
            }
        }
        elsif ( $value =~ /^\d+$/ ) {
             $datetype = 'userdefined';

             unless ( length( $value ) == 8 ) {
                 $logger->logdie("interactive variable '$name' has a invalid user defined date ($value)");
             }
        }
        else {
             $datetype = 'dateshifter';
        }

        $logger->debug("interactive variable '$name' of date type with as value '$value' specified");
    }
    else {
        $logger->logdie("wrong type specified for interactive variable '$name' ($type)");
    }

    return [ $name, $type, $datetype, $value, $entity ];
}

1;
