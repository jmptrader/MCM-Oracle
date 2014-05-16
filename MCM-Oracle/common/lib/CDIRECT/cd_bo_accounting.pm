package CDIRECT::cd_bo_accounting;

use CDIRECT::cd_cdirect;
use File::Copy;
use File::Basename;
use File::Glob;


our @ISA = qw(CDIRECT::cd_cdirect) ;

use warnings;
use strict;

#--------------------#
sub get_send         {
#--------------------#

    my ( $self ) = @_;

    my %mx_dates          = %{$self->{mx_dates}}  ;
    my $content           = $self->{content} ;

    ##If $is_holiday = 1 this means it's a holiday for this branch, so we do not send accounting

    if ( $mx_dates{ is_holiday } == 1 && $content eq 'ACCGEN' ) { $self->{send} = 'N' }  ;
    if ( $mx_dates{ is_holiday } == 1 && $content eq 'ACCGENNDM' ) { $self->{send} = 'N' }  ;

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

    my $logger            = $self->{logger} ;
    my $content           = $self->{content} ;
    my $target            = $self->{target} ;
    my $short_entity      = $self->{short_entity};
    my $runtype           = $self->{runtype} ;
    my %mx_dates          = %{$self->{mx_dates}}  ;
    my $env               = get_env( $self->{pillar} );
    my %filenumbers       = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '06', SH => '08', SI => '15', TW => '13', CT => '00', FP => '29' );
    my $filenumber        = $filenumbers{ $short_entity };
    my %files ;

    my $year           = substr( $mx_dates{ plcc_corr } , 2, 2 ) ;
    my $month          = substr( $mx_dates{ plcc_corr } , 4, 2 ) ;
    my $day            = substr( $mx_dates{ plcc_corr } , 6, 2 ) ;

    my $sys_year       = substr( $mx_dates{ sys_date } , 2, 2 ) ;
    my $sys_month      = substr( $mx_dates{ sys_date } , 4, 2 ) ;
    my $sys_day        = substr( $mx_dates{ sys_date } , 6, 2 ) ;

    if ( ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3') && $content eq 'ACCGEN' ) {

       my @filenames    = glob( $self->{localdir} . '/' . "Acc2Egate*${short_entity}.csv" );

       if ( ! @filenames ) {

           $logger->info ("CDIRECT INFO : no files found to send !!!");
           print "CDIRECT INFO : no files found to send !!! \n" ;
           exit 1 ;

       }

       foreach my $filename (@filenames) {
          chomp ( $filename );
          $self->{localfile} = basename($filename);
       }

    }

    if ( $target eq 'RDJ' ) {

       my  ( %file_branch_codes, $file_branch_code, %runtype_files, $runtype_file, $rundate ) ; 

       if ( $content eq 'ICO' ) { 
          %file_branch_codes = ( BR => 'KBC', CG => 'CBC', HK => 'KBC', SH => 'KBC', SI => 'KBC', FP => 'KBCI' ) ;
          $file_branch_code  = $file_branch_codes{ $short_entity };
          %runtype_files     = (  EOM_5 => '1', EOM => '2', 1 => '3', V => '4', X => '5' ) ;
          $runtype_file      = $runtype_files{ $runtype } ;
          $rundate           = $year . $month ;

          %files = ( ICO    => 'WRD' . $env . 'BI' . $short_entity . '.EXTN.TRX' . $file_branch_code . '.R' . $runtype_file . '.F' . $filenumber . '.M' . $rundate , );
       }

       if ( $content eq 'ACCGENNDM' ) {
          %runtype_files     = (  N => 'ACCEVT', O => 'ACCEVT', X => 'ACCEVT.COR' ) ;
          $runtype_file      = $runtype_files{ $runtype } ;
          $rundate           = $year . $month . $day ;

          %files = ( ACCGENNDM => 'WRD' . $env . 'BI' . $short_entity . '.EXTN.' . $runtype_file . '.D' . $rundate , ) ;
       }

          
       $self->{localfile} = $files{ $content };

    }

    if ( $target eq 'OV' ) {

       my $rundate   = $year . $month ;
       %files = ( UTR  => 'WOV' . $env . 'BI' . $short_entity . '.EXTN.DATAMART.F' . $filenumber . '.M' . $rundate , );

       $self->{localfile} = $files{ $content };

    }


    if ( $target eq 'ILRISK' ) {

       if ( $runtype eq 'X' ) {
         $year               = substr( $mx_dates{ last_cal_day } , 2, 2 ) ;
         $month              = substr( $mx_dates{ last_cal_day } , 4, 2 ) ;
         $day                = substr( $mx_dates{ last_cal_day } , 6, 2 ) ;
       }

       my $rundate = $day . $month . $year ;
       %filenumbers       = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '07', SH => '09', SI => '15', TW => '13', CT => '00', FP => '29' ); 
       $filenumber        = $filenumbers{ $short_entity };
       %files = ( ACCACO  => 'D' . $env . '.WMX.V.ACCACO.R0101.M.XML.S' . $rundate . '.C' . $filenumber, );

       $self->{localfile} = $files{ $content };

   }


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

    my $content      = $self->{content} ;
    my $target       = $self->{target} ;
    my %remotedirs ;


    if ( ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) && $content eq 'ACCGEN' ) {

       $self->{remotedir} = '/var/data/KBCB_ACCOUNTINGGL/MXG3/ft' ;

    }

    if ( $target eq 'ILRISK' ) {

       %remotedirs = ( ILRISK => {
                              ACCACO  => '/l70',
                            },
                      ) ;

       $self->{remotedir} = $remotedirs{ $target }{ $content } ;

    }

    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $content      = $self->{content} ;
    my $target       = $self->{target} ;
    my $short_entity = $self->{short_entity};
    my %mx_dates     = %{$self->{mx_dates}}  ;
    my $runtype      = $self->{runtype} ;

    $self->{remotefile} = $self->{localfile} ;

    if ( ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) && $content eq 'ACCGEN' ) {

       my $timestamp = $mx_dates{ cal_date } ;

       if ( $runtype eq 'O' || $runtype eq 'N' ) {

          $self->{remotefile} = "MXG3_${short_entity}_Accounting.$timestamp.dat";

       } else {

          $self->{remotefile} = "MXG3_COR_${short_entity}_Accounting.$timestamp.dat";

       }

    }


    return $self->{remotefile} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    my $target   = $self->{ target };

    if ( $target eq 'RDJ' || $target eq 'OV' ) {

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

       if ( $runtype eq 'X'  && $content eq 'ACCGENNDM' ) { $trigger_code = $trigger_corr_code ; } ;
       
       %mvs_trigger = ( ICO => 'WRDID' . $env . 'U' . $trigger_code ,
                        ACCGENNDM => 'WRDGM' . $env . 'U' . $trigger_code ,
                      );

       $self->{remotetrigger} = $mvs_trigger{ $content } ;

    }

    if (  $target eq 'OV'  ) {

       %mvs_trigger = ( UTR => 'WOV6P' . $env . 'U' . $trigger_code ) ;

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

  if ( $target eq 'RDJ' || $target eq 'OV' ) {

     my %files_width = ( RDJ => {
                                   ICO        => '4000' ,
                                   ACCGENNDM  => '4000' ,
                                   },
                          OV  => {
                                   UTR     => '2000',
                                   },
                          );

     $self->{recordlength} = $files_width{ $target }{ $content } ;

   }

  if ( ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) && $content eq 'ACCGEN' ) { 

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

  my $target   = $self->{ target };
  my $content      = $self->{ content };
  my %keyfiles ;

  if ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' ) { 

       if ( $content eq 'ACCGEN' ) { $self->{template_keyfile} =  'EGATE_TEMPLATE.key' ; } ;

  }

  if ( $target eq 'RDJ' ) {

       if ( $content eq 'ICO' || $content eq 'ACCGENNDM' ) { $self->{template_keyfile} =  'MVS_TEMPLATE_TRIGGER.key' ; } ;

  }

  if ( $target eq 'OV' ) {

       if (  $content eq 'UTR' ) { $self->{template_keyfile} =  'MVS_TEMPLATE_TRIGGER.key' ; } ;

  }

  if ( $target eq 'ILRISK' ) {

       if ( $content eq 'ACCACO' ) { $self->{template_keyfile} =  'ILRISK_TEMPLATE.key' ; } ;

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
