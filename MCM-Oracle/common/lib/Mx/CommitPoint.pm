package Mx::CommitPoint;

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase2;
use Carp;

#-------#
sub new {
#-------#
my ( $class, %args ) = @_;

my $logger = $args{logger} or croak 'no logger defined.';

my $self = {};
$self->{logger} = $logger;

my $config;
unless ( $config = $args{config} ) {
    $logger->logdie("missing argument in initialisation of commit object (config)");
}
$self->{config} = $config;

my $name;
unless ( $name = $args{name} ) {
    $logger->logdie( "missing argument in initialisation of commit object (name)" );
}
$self->{name} = $name;

my $descr;
unless ( $descr = $args{descr} ) {
    $logger->logdie( "missing argument in initialisation of commit object (descr)" );
}
$self->{descr} = $descr;

my $ckey;
unless ( $ckey = $args{ckey} ) {
    $logger->logdie( "missing argument in initialisation of commit object (ckey)" );
}
$self->{ckey} = $ckey;

my $cdate;
unless ( $cdate = $args{cdate} ) {
    $logger->logdie( "missing argument in initialisation of commit object (cdate)" );
}
$self->{cdate} = $cdate;

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MONUSER, config => $config, logger => $logger );
my $database = $config->MONDB_NAME;

#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $database, username => $account->name, password => $account->password, error_handler => 0, logger => $logger, config => $config );

#
# open the Sybase connection
#
unless ( $sybase->open() ) {
    $logger->logdie("unable to connect to monitoring database $database");
}

$self->{sybase}      = $sybase;
$self->{code}        = '';
$self->{returncode}  = 0;
$self->{resultname}  = '';
$self->{resultcode}  = '';
$self->{resultdescr} = '';
$self->{resultckey}  = '';
$self->{resultcdate} = '';

bless $self, $class;
}

#---------------------#
sub start_commitpoint {
#---------------------#

my ( $self, %args ) = @_;

my $checkquery  = "select NAME, CODE, DESCR, CDATE, CKEY from commitpoints where NAME = ? and CDATE = ?";
my $insert      = "insert into commitpoints values ( ?, ?, ?, ?, ? )";    
my $values      = [ $self->{name}, $self->{cdate} ];
my $sybase      = $self->{sybase};
my $logger      = $self->{logger};
my $code        = 'S';

my $checkresult; 
unless ( $checkresult = $sybase->query( query => $checkquery, logger => $logger, values => $values, quiet => 1 ) ) {
    $logger->logdie( "Commit check query failed" );
} 

if ( $checkresult->size ) {
    if ( $checkresult->size != 1 ) {
        $logger->logdie( "Multiple instances detected for commitpoint: ", $self->{name},"-",$self->{cdate} );
    }

    my %row = $checkresult->next_hash;
    $self->{returncode}  = -10;                                # restart detected code
    $self->{resultname}  = $row{'NAME'};
    $self->{resultcode}  = $row{'CODE'};
    $self->{resultdescr} = $row{'DESCR'};
    $self->{resultckey}  = $row{'CKEY'};
    $self->{name}        = $row{'NAME'};
    $self->{code}        = $row{'CODE'};
    $self->{descr}       = $row{'DESCR'};
    $self->{ckey}        = $row{'CKEY'};
    $self->{cdate}       = $row{'CDATE'};
    $logger->info( "Name detected in commitpoint table: ", $self->{name}, " for date: ", $self->{cdate} );
}
else {
    $values = [ $self->{name}, $code, $self->{descr}, $self->{cdate}, $self->{ckey} ]; 

    my $insresult;
    unless ( $insresult = $sybase->do( statement => $insert, logger => $logger, values => $values, quiet => 1 ) ) {
        $logger->logdie( "Insert commit point failed" );
    } 

    $self->{returncode}  = 0;
    $self->{resultname}  = '';
    $self->{resultcode}  = '';
    $self->{resultdescr} = '';
    $self->{resultckey}  = '';
    $self->{resultcdate} = '';
    $logger->info( "No previous commit detected in commitpoint table." );
}

}

#----------------------#
sub update_commitpoint {
#----------------------#

my ( $self, %args ) = @_;

my $logger = $self->{logger};
my $sybase = $self->{sybase};
my $code   = 'U';
my $update = "update commitpoints set CODE = ?, CKEY = ? where NAME = ?";

my $ckey;
unless ( $ckey = $args{ckey} ) {
    $logger->logdie( "missing argument in update of commit (ckey)" );
}

my $values = [ $code, $ckey, $self->{name} ];

my $updresult;
unless ( $updresult = $sybase->do( statement => $update, logger => $logger, values => $values, quiet => 1 ) ) {
    $logger->logdie( "Insert commit point failed" );
}

if ( ( $updresult + 0 ) == 0 ) {
    $logger->logdie( "no previous commit record found: ", $self->{name} );
}

$logger->info( "commitpoint updated: ", $self->{name}."-".$code."-".$ckey );

$self->{ckey}  = $ckey;
$self->{code}  = $code;

}

#-------------------#
sub end_commitpoint {
#-------------------#

my ( $self, %args ) = @_;

my $logger = $self->{logger};
my $sybase = $self->{sybase};
my $delete = "delete from commitpoints where NAME = ?";

my $values = [ $self->{name} ];

my $delresult;
unless ( $delresult = $sybase->do( statement => $delete, logger => $logger, values => $values, quiet => 1 ) ) {
    $logger->logdie( "Delete commit point failed" );
}

if ( ( $delresult + 0 ) != 1 ) {
    $logger->logdie( "More than 1 or 0 records found to delete: ", $self->{name} );
}

$logger->info( "commitpoint deleted: ", $self->{name} );

$self->{sybase}->close;

}

#--------#
sub name {
#--------#

my ( $self, $name ) = @_;
$self->{name} = $name if defined $name;

return $self->{name};
}

#--------#
sub code {
#--------#

my ( $self, $code ) = @_;
$self->{code} = $code if defined $code;

return $self->{code};
}

#---------#
sub descr {
#---------#

my ( $self, $descr ) = @_;
$self->{descr} = $descr if defined $descr;

return $self->{descr};
}

#--------#
sub ckey {
#--------#

my ( $self, $ckey ) = @_;
$self->{ckey} = $ckey if defined $ckey;

return $self->{ckey};
}

#--------------#
sub returncode {
#--------------#

my ( $self, $returncode ) = @_;
$self->{returncode} = $returncode if defined $returncode;

return $self->{returncode};
}

#---------#
sub cdate {
#---------#

my ( $self, $cdate ) = @_;
$self->{cdate} = $cdate if defined $cdate;

return $self->{cdate};
}

1;
