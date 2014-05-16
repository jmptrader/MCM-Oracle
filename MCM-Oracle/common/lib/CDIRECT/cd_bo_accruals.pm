package CDIRECT::cd_bo_accruals;

use CDIRECT::cd_cdirect;

our @ISA = qw(CDIRECT::cd_cdirect) ;

use File::Copy;
use File::Basename;
use File::Glob;

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

    my %files ;

    my $year           = substr( $mx_dates{ plcc_date } , 2, 2 ) ;
    my $month          = substr( $mx_dates{ plcc_date } , 4, 2 ) ;
    my $day            = substr( $mx_dates{ plcc_date } , 6, 2 ) ;

    if ( $content eq 'IRS' || $content eq 'FRD' ) {

      my @filenames    = glob( $self->{localdir} . '/' . "*_${content}_${short_entity}.csv" );

      if ( ! @filenames ) {

         $logger->info ("CDIRECT INFO : no files found to send !!!");
         exit 0 ;

      }

      foreach my $filename (@filenames) {
          chomp ( $filename );
          $self->{localfile} = basename($filename);
      }


      if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
         print "Could not open file $self->{localdir}/$self->{localfile} !!! \n" ;
         $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
      }


    }

    if ( $target eq 'RDJ' ) {

      my %runtype_files     = (  N => 'ACCRU', O => 'ACCRU', X => 'ACCRU.COR' ) ;
      my $runtype_file      = $runtype_files{ $runtype } ;
      my $rundate           = $year . $month . $day ;

      %files = ( ACCRUNDM => 'WRD' . $env . 'BI' . $short_entity . '.EXTN.' . $runtype_file . '.D' . $rundate , ) ;

      $self->{localfile} = $files{ $content };

    }

    return $self->{localfile} ;

}


#-----------------#
sub get_remotedir {
#-----------------#

    my ( $self ) = @_;

    $self->{remotedir} = '/var/data/KBCB_ACCOUNTINGGL/MXG3/ft/tmp' ;


    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $short_entity = $self->{short_entity};

    my $content      = $self->{content} ;
    my $target       = $self->{ target };

    my $timestamp = $self->calendardate() ;

    if ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) {

       $self->{remotefile} = "MXG3_${short_entity}_${content}_Proratering.$timestamp.dat";

    } else {

       $self->{remotefile} = $self->{localfile} ;

    }

    return $self->{remotefile} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    my $target   = $self->{ target };

    if ( $target eq 'RDJ' ) {

      my %remote_jobs = ( O => 'CERATST', A => 'CERAK', P => 'CERA' ) ;

      $self->{remotejob} = $remote_jobs { $self->{pillar} } ;

    }


    return $self->{remotejob} ;

}


#---------------------#
sub get_remotetrigger {
#---------------------#

    my ( $self ) = @_;

    my $content            = $self->{ content };
    my $target             = $self->{ target };
    my $runtype            = $self->{runtype} ;
    my $short_entity       = $self->{ short_entity };
    my $env                = get_env( $self->{pillar} );
    my %trigger_codes      = ( BR => 'B', CG => 'G', FR => 'F', LO => 'L', NL => 'N', HK => 'H', SH => 'A', SI => 'S', TW => 'T', CT => 'C', FP => 'P' );
    my %trigger_corr_codes = ( BR => '1', CG => '2', FR => '0', LO => '3', NL => '0', HK => '6', SH => '5', SI => '4', TW => '0', CT => '0', FP => '7' );
    my $trigger_code       = $trigger_codes{ $short_entity } ;
    my $trigger_corr_code  = $trigger_corr_codes{ $short_entity } ;
    my %mvs_trigger ;


    if ( $target eq 'RDJ' ) {

       if ( $runtype eq 'X'  && $content eq 'ACCRUNDM' ) { $trigger_code = $trigger_corr_code ; } ;

       %mvs_trigger = ( ACCRUNDM => 'WRDAC' . $env . 'U' . $trigger_code ,
                      );

       $self->{remotetrigger} = $mvs_trigger{ $content } ;

    }


    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

  my ( $self ) = @_;

  my $content      = $self->{ content };
  my $target       = $self->{ target };

  if ( $target eq 'RDJ') {

     my %files_width = ( RDJ => {
                                   ACCRUNDM  => '4000' ,
                                   },
                          );

     $self->{recordlength} = $files_width{ $target }{ $content } ;

   }

  if ( ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) && ( $content eq 'IRS' || $content eq 'FRD' ) ) {

    my $filewidth = 0 ;

    if ( ! -z $self->{localdir} . '/' . $self->{localfile} ) {

      open (READLINE, $self->{localdir} . '/' . $self->{localfile} ) ;
        my $text = <READLINE> ;
        $filewidth = length($text) ;
      close (READLINE);

    }

    $self->{recordlength} = $filewidth ;

  }


  return $self->{recordlength} ;


}

#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  my $content   = $self->{ content };
  my $target   = $self->{ target };

  if ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) {

       if ( $content eq 'IRS' || $content eq 'FRD' )  { $self->{template_keyfile} =  'EGATE_TEMPLATE.key' ; } ;

  }

  if ( $target eq 'RDJ' ) {

       if ( $content eq 'ACCRUNDM' ) { $self->{template_keyfile} =  'MVS_TEMPLATE_TRIGGER.key' ; } ;

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


#----------------#
sub calendardate {
#----------------#
    my ($sec,$min,$hour,$day, $month, $year) = ( localtime( time() ) )[0..5];
    return sprintf "%04s%02s%02s%02s%02s%02s", $year + 1900, ++$month, $day,$hour,$min,$sec;
}

1;
