package Mx::Auth::Environment;

use strict;
use warnings;

use Mx::Log;
use Mx::Config;
use Mx::Auth::DB;
use Mx::Database::ResultSet;
use Mx::Semaphore;
use Carp;

#
# properties:
#
# id
# name
# description
# pillar
# samba_read
# samba_write
# config_data
# disabled
#
# extended properties:
#
# sybversion
# dbversion
# binversion
# contactid
#

my @PILLARS = ( 'O', 'S', 'A', 'P' );


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    if ( $args{id} ) {
        $self->{id}   = $args{id};
        $self->{name} = $args{name};
    }
    elsif ( $args{name} ) {
        $self->{name} = $args{name};
    }
    else {
        $logger->logdie("missing argument in initialisation of environment (id or name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of environment (config)");
    }
    $self->{config} = $config;

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in initialisation of environment (db)");
    }
    $self->{db} = $db;

    $self->{description} = $args{description};

    my $pillar = $self->{pillar} = $args{pillar};
    if ( $pillar && ! grep /^$pillar$/, @PILLARS ) {
        $logger->logdie("$pillar is not a valid environment pillar");
    }

    $self->{samba_read}  = $args{samba_read};
    $self->{samba_write} = $args{samba_write};
    $self->{config_data} = $args{config_data};
    $self->{disabled}    = $args{disabled};

    if (defined($args{sybversion})) {
      $self->{sybversion}  = $args{sybversion};
      $self->{dbversion}   = $args{dbversion};
      $self->{binversion}  = $args{binversion};
      $self->{contactid}   = $args{contactid};
    }

    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $db     = $self->{db};

    my $query = 'select id, name, description, pillar, samba_read, samba_write, config_data, disabled from environments';

    my $query_key; my $value;
    if ( $value = $self->{id} ) {
        $query_key = 'environment_select_by_id'; 
    }
    elsif ( $value = $self->{name} ) {
        $query_key = 'environment_select_by_name'; 
    }

    my $result = $db->query( query_key => $query_key, values => [ $value ] );

    if ( $result->size == 0 ) {
        $logger->error("environment $value can not be retrieved");
        return;
    }

    if ( $result->size > 1 ) {
        $logger->error("environment $value retrieved more than once");
        return;
    }

    my %hash = $result->next_hash;

    $self->{id}          = $hash{id};
    $self->{name}        = $hash{name};
    $self->{description} = $hash{description};
    $self->{pillar}      = $hash{pillar};
    $self->{samba_read}  = $hash{samba_read};
    $self->{samba_write} = $hash{samba_write};
    $self->{config_data} = $hash{config_data};
    $self->{disabled}    = ( $hash{disabled} eq 'Y' ) ? 1 : 0;

    return 1;
}

#---------------------#
sub retrieve_extended {
#---------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $db     = $self->{db};
    my $id     = $self->{id};

    my $result = $db->query ( query_key => 'environment_extended_select' , values => [ $id , $id ] );

    if ( ! defined($result) ) {
        $logger->error("environment_exteded $id did not yield anything");
        return 0;
    }

    if ( $result->size == 0 ) {
        $logger->info("environment_extended $id can not be retrieved");
    }

    if ( $result->size > 1 ) {
        $logger->error("environment_extended $id retrieved more than once");
        return 0;
    }

    my %hash = $result->next_hash;

    $self->{sybversion}  = $hash{sybase_version};
    $self->{dbversion}   = $hash{db_version};
    $self->{binversion}  = $hash{binary_version};
    $self->{contactid}   = $hash{contact_id};

    return 1;
}
#----------------#
sub retrieve_all {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in environment retrieval (config)");
    }

    my $db;
    unless ( $db = $args{db} ) {
        $logger->logdie("missing argument in environment retrieval (db)");
    }

    my $result = $db->query( query_key => 'environment_select' );

    my @environments = ();
    while ( my ( $id, $name, $description, $pillar, $samba_read, $samba_write, $config_data, $disabled ) = $result->next ) {
        push @environments, Mx::Auth::Environment->new( id => $id, name => $name, description => $description, pillar => $pillar, samba_read => $samba_read, samba_write => $samba_write, config_data => $config_data, disabled => $disabled, db => $db, logger => $logger, config => $config );
    }

    return @environments;
}

#----------#
sub insert {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};
    my $db     = $self->{db};

    my $semaphore = Mx::Semaphore->new( key => 'auth_environments', create => 1, logger => $logger, config => $config );

    $semaphore->acquire();

    $self->{id} = $db->next_id( table => 'environments' );

    my $disabled = ( $self->{disabled} ) ? 'Y' : 'N';

    my @values = ( $self->{id}, $self->{name}, $self->{description}, $self->{pillar}, $self->{samba_read}, $self->{samba_write}, $self->{config_data}, $disabled );
    my $nr_rows = $db->do( statement_key => 'environment_insert', values => [ @values ] );

    @values = ( $self->{id}, $self->{sybversion}, $self->{dbversion}, $self->{binversion} );
    $db->do( statement_key => 'environment_info_insert', values => [ @values ] );

    @values = ( $self->{id}, $self->{contactid} );
    $db->do( statement_key => 'environment_contacts_insert', values => [ @values ] );

    $semaphore->release();

    return $nr_rows;
}

#----------#
sub update {
#----------#
    my ( $self ) = @_;

    my $logger   = $self->{logger};
    my $db       = $self->{db};
    my $disabled = ( $self->{disabled} ) ? 'Y' : 'N';

    my @values = ( $self->{name}, $self->{description}, $self->{pillar}, $self->{samba_read}, $self->{samba_write}, $self->{config_data}, $disabled, $self->{id} );
    my $nr_rows = $db->do( statement_key => 'environment_update', values => [ @values ] );

    @values = ( $self->{sybversion}, $self->{dbversion}, $self->{binversion}, $self->{id} );
    $db->do ( statement_key => 'environment_info_update', values => [ @values ] );

    @values = ( $self->{contactid}, $self->{id} );
    $db->do ( statement_key => 'environment_contacts_update', values => [ @values ] );

    return $nr_rows;
}

#----------#
sub delete {
#----------#
    my ( $self ) = @_;

    my $db       = $self->{db};

    my $nr_rows = $self->{db}->do( statement_key => 'environment_delete', values => [ $self->{id} ] );

    $self->{db}->do( statement_key => 'environment_info_delete', values => [ $self->{id} ] );
    $self->{db}->do( statement_key => 'environment_contacts_delete', values => [ $self->{id} ] );

    return $nr_rows;
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#--------#
sub name {
#--------#
    my ( $self, $name ) = @_;

    $self->{name} = $name if defined $name;
    return $self->{name};
}

#---------------#
sub description {
#---------------#
    my ( $self, $description ) = @_;

    $self->{description} = $description if defined $description;
    return $self->{description};
}

#----------#
sub pillar {
#----------#
    my ( $self, $pillar ) = @_;

    $self->{pillar} = $pillar if defined $pillar;
    return $self->{pillar};
}

#--------------#
sub samba_read {
#--------------#
    my ( $self, $samba_read ) = @_;

    $self->{samba_read} = $samba_read if defined $samba_read;
    return $self->{samba_read};
}

#---------------#
sub samba_write {
#---------------#
    my ( $self, $samba_write ) = @_;

    $self->{samba_write} = $samba_write if defined $samba_write;
    return $self->{samba_write};
}

#---------------#
sub config_data {
#---------------#
    my ( $self, $config_data ) = @_;

    $self->{config_data} = $config_data if defined $config_data;
    return $self->{config_data};
}

#------------#
sub disabled {
#------------#
    my ( $self, $disabled ) = @_;

    $self->{disabled} = $disabled if defined $disabled;
    return $self->{disabled};
}

#--------------#
sub sybversion {
#--------------#
    my ( $self, $sybversion ) = @_;

    $self->{sybversion} = $sybversion if defined $sybversion;
    return $self->{sybversion};
}

#-------------#
sub dbversion {
#-------------#
    my ( $self, $dbversion ) = @_;

    $self->{dbversion} = $dbversion if defined $dbversion;
    return $self->{dbversion};
}

#--------------#
sub binversion {
#--------------#
    my ( $self, $binversion ) = @_;

    $self->{binversion} = $binversion if defined $binversion;
    return $self->{binversion};
}

#-------------#
sub contactid {
#-------------#
    my ( $self, $contactid ) = @_;

    $self->{contactid} = $contactid if defined $contactid;
    return $self->{contactid};
}

#-----------#
sub pillars {
#-----------#
    my ( $class ) = @_;

    return @PILLARS;
}


1;
