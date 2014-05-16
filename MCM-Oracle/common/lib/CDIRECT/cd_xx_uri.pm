package CDIRECT::cd_xx_uri;

use CDIRECT::cd_cdirect;

our @ISA = qw(CDIRECT::cd_cdirect) ;

use warnings;
use strict;

#--------------------#
sub get_send         {
#--------------------#

    my ( $self ) = @_;

    return $self->{send} ;

}


#--------------------#
sub get_audit        {
#--------------------#

    my ( $self ) = @_;

    return $self->{audit} ;

}


#----------------#
sub get_localdir {
#----------------#

    my ( $self ) = @_;

    my $localdir = $self->{config}->KBC_TRANSFERDIR ;

    $self->{localdir} = $localdir ;


    return $self->{localdir} ;

}


#-----------------#
sub get_localfile {
#-----------------#

    my ( $self ) = @_;

    my $logger       = $self->{logger} ;
    my $content      = $self->{content} ;
    my $target       = $self->{target} ;
    my $short_entity = $self->{short_entity};
    my $runtype      = $self->{runtype} ;
    my %mx_dates     = %{$self->{mx_dates}}  ;
    my $env          = get_env( $self->{pillar} );

    my $year           = substr( $mx_dates{ plcc_date } , 2, 2 ) ;
    my $month          = substr( $mx_dates{ plcc_date } , 4, 2 ) ;
    my $day            = substr( $mx_dates{ plcc_date } , 6, 2 ) ; 
    my $rundate_uri    = $year . $month . $day ;
    my $rundate_amam   = $year . $month . $day ;

    if ( $target eq 'MVS' && $content eq 'URISWP' ) { $self->{localfile} = 'CAD' . $env . 'B000.EXTN.URI.SWAPS.CAD06' . $env . 'U3.D' . $rundate_uri ; } ;   
    if ( $target eq 'MVS' && $content eq 'AMAM' )   { $self->{localfile} = 'CAD' . $env . 'B000.EXTN.URI.EFF.MRX.CAD04' . $env . 'U3.D' . $rundate_amam ; } ;


    if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
       print "Could not open file $self->{localdir}/$self->{localfile} !!! \n" ;
       $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
    }

    return $self->{localfile} ;

}


#-----------------#
sub get_remotedir {
#-----------------#

    my ( $self ) = @_;

    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    $self->{remotefile} = $self->{localfile} ; 

    return $self->{remotefile} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    my $target       = $self->{ target };

    if ( $target eq 'MVS' ) {

      my %remote_jobs = ( O => "CERATST", A => "CERAK", P => "CERA" ) ;

      $self->{remotejob} = $remote_jobs{ $self->{pillar} } ;

    }

    return $self->{remotejob} ;

}


#---------------------#
sub get_remotetrigger {
#---------------------#

    my ( $self ) = @_;

    my $content      = $self->{ content };
    my $target       = $self->{ target };
    my $short_entity = $self->{ short_entity };
    my $runtype      = $self->{ runtype };
    my $trigger      = $self->{ remotetrigger } ;
    my $env          = get_env( $self->{pillar} );
    my %mvs_trigger ;

    if ( $target eq 'MVS' && $content eq 'URISWP') { $self->{remotetrigger} = 'CAD06' . $env . 'U3' ; } ;
    if ( $target eq 'MVS' && $content eq 'AMAM')   { $self->{remotetrigger} = 'CAD04' . $env . 'U3' ; } ;

    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

    my ( $self ) = @_;


    my $target       = $self->{ target };

    if ( $target eq 'MVS' ) {

        $self->{recordlength} = '999' ;

    }

    return $self->{recordlength} ;

}




#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  my $content      = $self->{ content };
  my $target       = $self->{ target };
  my %keyfiles ;

  if ( $target eq 'MVS' ) {

      $self->{template_keyfile} = 'MVS_TEMPLATE_TRIGGER.key' ;

  }

  return $self->{template_keyfile} ;

}

#------------------#
sub get_wmxkeyfile {
#------------------#

  my ( $self ) = @_;

  my $content      = $self->{ content };
  my $target       = $self->{ target };
  my $short_entity = $self->{ short_entity };
  my $runtype      = $self->{ runtype };

  $self->{wmx_keyfile} = $target . '_' . $short_entity . '_' . $runtype . '_' . $content . '.key' ;


  return $self->{wmx_keyfile} ;

}


#-----------#
sub get_env {
#-----------#

    my ($pillar) = @_;
    my $env;

    SWITCH: {
        $pillar eq 'P' && do { $env = 'P'; last SWITCH; };
        $pillar eq 'A' && do { $env = 'K'; last SWITCH; };
        $env = 'T';
    }

    return ( $env );

}


1;
