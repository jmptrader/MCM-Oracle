package Mx::Filter;

use strict;

use Carp;
use Mx::Portfolio;

#
# properties:
#
# label
# index
# portfolios
# products
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

    my $batch_configfile = $config->retrieve('BATCH_CONFIGFILE');
    my $batch_config     = Mx::Config->new( $batch_configfile );

    my $sybase;
    unless ( $sybase = $self->{sybase} = $args{sybase} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (sybase)");
    }

    my $library;
    unless ( $library = $self->{library} = $args{library} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (library)");
    }

    my $label;
    unless ( $label = $self->{label} = $args{label} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (label)");
    }

    my $index;
    unless ( exists $args{index} ) {
        $logger->logdie("missing argument in initialisation of Murex filter (index)");
    }
    $index = $self->{index} = $args{index};

    unless ( $index =~ /^[01234]$/ ) {
        $logger->logdie("wrong index used for filter '$label': $index");
    }
 
    unless ( $batch_config->retrieve("BATCHES.$label", 1) ) {
        $logger->info("batch '$label' is not defined in the configuration file");
        return;
    }

    my $filter_ref;
    if ( $filter_ref = $batch_config->retrieve("BATCHES.$label.FILTER$index", 1) ) {
        $logger->info("filter '${label}/FILTER${index}' found in the configuration file");
    }
    elsif ( $filter_ref = $batch_config->retrieve("BATCHES.$label.FILTER", 1) ) {
        $logger->info("filter '${label}/FILTER' found in the configuration file");
    }
    else {
        $logger->info("filter '$label' is empty");
        return;
    }

    my @portfolio_names = my @portfolios = ();
    if ( exists $filter_ref->{portfolio} ) {
        if ( ref( $filter_ref->{portfolio} ) eq 'ARRAY' ) {
            @portfolio_names = @{$filter_ref->{portfolio}};
        }
        else {
            @portfolio_names = ( $filter_ref->{portfolio} );
        }
    }

    my @product_names = my @products = ();
    if ( exists $filter_ref->{product} ) {
        if ( ref( $filter_ref->{product} ) eq 'ARRAY' ) {
            @product_names = @{$filter_ref->{product}};
        }
        else {
            @product_names = ( $filter_ref->{product} );
        }
    }

    foreach my $name ( @portfolio_names ) {
        push @portfolios, Mx::Portfolio->new( name => $name, sybase => $sybase, library => $library, config => $config, logger => $logger );
    }

    foreach my $product ( @product_names ) {
        push @products, _normalize_product( $self, $product );
    }

    unless ( @portfolios or @products ) {
        return;
    }

    $self->{portfolios} = \@portfolios;
    $self->{products}   = \@products;

    bless $self, $class;
}


#-----------#
sub install {
#-----------#
    my ( $self, %args ) = @_;


    my $logger  = $self->{logger} or return;
    my $sybase  = $self->{sybase};
    my $library = $self->{library};
    my $label   = $self->{label};
    my $index   = $self->{index};

    my @portfolios  = @{ $self->{portfolios} };
    my @products    = @{ $self->{products} };

    my $batch;
    unless ( $batch = $args{batch} ) {
        $logger->logdie("missing argument in filter installation (batch)");
    }

    my $statement;
    unless ( $statement = $library->query('delete_filter') ) {
        $logger->logdie("cannot retrieve query 'delete_filter' from the SQL library");
    }

    unless ( $sybase->do( statement => $statement, values => [ $batch, $index ] ) ) {
        $logger->logdie("cannot cleanup old filter for batch '$batch'");
    }

    unless ( $statement = $library->query('install_filter') ) {
        $logger->logdie("cannot retrieve query 'install_filter' from the SQL library");
    }

    foreach my $portfolio ( @portfolios ) {
        unless ( $sybase->do( statement => $statement, values => [ 'DYNDBF PORTFOLIO', $batch, $index, $portfolio->name, $portfolio->type ] ) ) {
            $logger->logdie("cannot install filter '$label': insert of portfolio '" . $portfolio->name . "' failed");
        }
    }

    foreach my $product ( @products ) {
        unless ( $sybase->do( statement => $statement, values => [ 'DYNDBF TRN. TYPE', $batch, $index, $product, 'C' ] ) ) {
            $logger->logdie("cannot install filter '$label': insert of product '" . $product . "' failed");
        }
    }

    return 1;
}


#---------#
sub label {
#---------#
    my ( $self ) = @_;

    return $self->{label};
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

    $product = sprintf "%-5s|%-5s|%-5s", $family, $group, $type;

    $logger->debug("normalized product is '$product'");

    return $product;
}
   
1;
