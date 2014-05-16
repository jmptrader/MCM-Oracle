package Mx::FileCleanup;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;

use File::stat;
use Time::localtime;


#
# Attributes:
#
# name                     name of the config section to clean a specif type of fil
# directory                directory which contains the files to clean
# retention_days           clean older then x days
# file_types               which files to clean, could be a regular expression 
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
    my $name;

    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of cleanup procedure (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of cleanup procedure (config)");
    }

    my $cleanup_configfile = $config->retrieve('CLEANFS_CONFIGFILE');
    my $cleanup_config     = Mx::Config->new( $cleanup_configfile );

    my $cleanup_ref;
    unless ( $cleanup_ref = $cleanup_config->retrieve("%CLEANFS%$name") ) {
        $logger->logdie("cleanup '$name' is not defined in the configuration file");
    }

    foreach my $param (qw( directory retention_days file_types )) {
        unless ( exists $cleanup_ref->{$param} ) {
            $logger->logdie("parameter '$param' for cleanup '$name' is not defined in the configuration file");
        }
        $self->{$param} = $cleanup_ref->{$param};
    }

    #
    # validate directory to clean
    #

    while ( $self->{ directory } =~ /__(\w+)__/ ) {
        my $before = $`;
        my $ph     = $1;
        my $after  = $';
        $self->{ directory } = $before . $config->retrieve( $ph ) . $after;

        if ( ! -d $self->{ directory } ) {
	   $logger->info("Directory to clean does not exist : " . $self->{ directory } ) ;
        }
    }

    #
    # validate file_types
    #

    my @file_types = split ',', $self->{ file_types };
    $self->{ file_types } = [ @file_types ];


    $logger->info("Cleanup $name initialized");

    bless $self, $class;

    return $self;
}


#----------------#
sub retrieve_all {
#----------------#

   my ( $class, %args ) = @_;


    my @cleanups = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $cleanup_configfile = $config->retrieve('CLEANFS_CONFIGFILE');
    my $cleanup_config     = Mx::Config->new( $cleanup_configfile );

    my $cleanup_ref;
    unless ( $cleanup_ref = $cleanup_config->CLEANFS ) {
        $logger->logdie("cannot access the fscleanup section in the configuration file");
    }

    foreach my $name ( keys %{$cleanup_ref} ) {
        my $cleanup = Mx::FileCleanup->new( name => $name, config => $config, logger => $logger );
        push @cleanups, $cleanup;
    }

    return @cleanups;
}


#----------------#
sub delete       {
#----------------#

    my ( $self, %args ) = @_;


    my $logger         = $self->{logger};
    my $name           = $self->{name};
    my $directory      = $self->{directory};
    my $retention_days = $self->{retention_days};
    my @file_types     = @{$self->{file_types}} ;
    my $clean_date     = time() - $retention_days * 86400 ;

    foreach my $file_type ( @file_types ) {

       my $delete_nbr = 0 ;

       $logger->info ("Cleaning dir: $directory.") ;
       $logger->info ("File_type : $file_type.")  ;

       opendir DIR, $directory ;

       while ( my $file = readdir( DIR ) ) {

         my $date = stat($directory.'/'.$file)->mtime;
         if ( $file =~ /^($file_type)$/ &&  $date < $clean_date ) {
           my $filename = $directory.'/'.$file ;
           $delete_nbr += unlink "$filename" ;
         }
      
       }

       $logger->info ("$delete_nbr files deleted. ") ;

       closedir( DIR );

    }

}


1;
