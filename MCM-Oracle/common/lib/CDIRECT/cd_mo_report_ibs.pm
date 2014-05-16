package CDIRECT::cd_mo_report_ibs;

use CDIRECT::cd_cdirect;

our @ISA = qw(CDIRECT::cd_cdirect) ;

use warnings;
use strict;

#--------------------#
sub get_send         {
#--------------------#

    my ( $self ) = @_;

    my $logger       = $self->{logger} ;
    my $short_entity = $self->{short_entity};
    my $content      = $self->{content} ;
    my $pillar       = $self->{pillar} ;

    if ( $pillar eq 'O' ) {

        ##Sint only BR and LO
        ##But only on request, so currently all set to N.

        my %opt     = ( HK => 'N', SH => 'N', SI => 'N',TW => 'N', BR => 'N', CG => 'N', NL => 'N', FR => 'N', LO => 'N', FP => 'N');
        my %frd     = ( HK => 'N', SH => 'N', SI => 'N',TW => 'N', BR => 'N', CG => 'N', NL => 'N', FR => 'N', LO => 'N', FP => 'N');
        my %irs_old = ( HK => 'N', SH => 'N', SI => 'N',TW => 'N', BR => 'N', CG => 'N', NL => 'N', FR => 'N', LO => 'N', FP => 'N');
     
        if ( $content eq "OPT" )     { $self->{send} = $opt{ $short_entity }; };
        if ( $content eq "FRD" )     { $self->{send} = $frd{ $short_entity }; };
        if ( $content eq "IRS_OLD" ) { $self->{send} = $irs_old{ $short_entity }; };

     }

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
    my %filenumbers  = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '07', SH => '09', SI => '15', TW => '13', CT => '00', FP => '29' );
    my %mifidcodes   = ( BR => 'UO', CG => 'BO', FR => 'XX', LO => 'XX', NL => 'XX', HK => 'XX', SH => 'XX', SI => 'XX', TW => 'XX', CT => 'XX', FP => 'XX' ) ;
    my $filenumber   = $filenumbers{ $short_entity };
    my $mifidcode    = $mifidcodes{ $short_entity };
    my %files ;

    my %runtype_files = ( IBS    => { O => 'O' , 1 => '1' , V => 'VX', X => 'VX' },
                          SENTRY => { O => 'D' , 1 => 'C' , V => 'C',  X => 'M'  },
                          ILRISK => { O => 'D' , 1 => 'C' , V => 'C',  X => 'M'  },
                          EMS    => { O => 'D' , 1 => 'C' , V => 'C',  X => 'M'  },
                        );

    my $runtype_file = $runtype_files{ $target }{ $runtype } ; 

    my $rundate_mtm        = substr( $mx_dates{ plcc_date }, 2 ) ;
    my $year               = substr( $mx_dates{ plcc_corr } , 2, 2 ) ;
    my $month              = substr( $mx_dates{ plcc_corr } , 4, 2 ) ;
    my $day                = substr( $mx_dates{ plcc_corr } , 6, 2 ) ; 
    my $rundate_mktval_ems = $year . $month . $day ;

    if ( $runtype eq 'X' ) {

     $year               = substr( $mx_dates{ last_cal_day } , 2, 2 ) ;
     $month              = substr( $mx_dates{ last_cal_day } , 4, 2 ) ;
     $day                = substr( $mx_dates{ last_cal_day } , 6, 2 ) ;

    }

    my $rundate_mktval     = $day . $month . $year ;

    if ( $target eq 'IBS' || $target eq 'EMS' ) {    

       %files = ( IBS => {  
                            IRS     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.IRS.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            IRC     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.IRC.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            FRA     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.FRA.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            OPT     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.OPT.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            FRD     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.LOA.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            VCR     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.MTM.VCR'                             . '.D'       . $rundate_mtm ,
                            IRS_OLD => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.F2F6308.SWAPS.MUREX' . $runtype_file . '.D'       . $rundate_mtm ,
                            LOA     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.LOA.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            FXD     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.FXD.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            FUT     => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.FUT.RUN'             . $runtype_file .'.MUREX.D'  . $rundate_mtm ,
                            FUTM    => 'WF2' . $env . 'BI' . $short_entity . '.EXTN.FUT.RUNM'                            .'.MUREX.D'  . $rundate_mtm ,
                            MIFID   => 'WFA' . $env . 'BI' . $short_entity . '.EXTN.FFSMA.MUREX.'        . $short_entity . $mifidcode . '.D' . $rundate_mtm ,
                         },

                  EMS => {
                            MKTVAL  => 'WF6' . $env . 'BICT.EXTN.MKTVAL.' . $short_entity . '.D' . $rundate_mktval_ems ,
                         },

                    ) ;

      $self->{localfile} = $files{ $target }{ $content };

      #### TEMP SOLUTION FOR FR/NL/FP

      if ( $short_entity eq "NL" || $short_entity eq "FR" || $short_entity eq "FP" ) {

         if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
            print "File not found, sending dummy file ... \n";
            $logger->info('Sending dummy file ... ') ;
            open (OUTPUTFILE, ">$self->{localdir}/$self->{localfile}") || $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
            close (OUTPUTFILE) || $logger->logdie ("Can't close $!");
         }
      }

    }

    if ( $target eq 'ILRISK' || $target eq 'SENTRY' ) { 

       %files = ( ILRISK => {
                              MKTVAL  => 'D' . $env . '.WMX.V.MKTVAL.R0200.' . $runtype_file . '.XML.S' . $rundate_mktval . '.C' . $filenumber,
                            },

                 SENTRY => {
                              MKTVAL  => 'D' . $env . '.WMX.V.MKTVAL.R0200.' . $runtype_file . '.XML.S' . $rundate_mktval . '.C' . $filenumber,
                           },

                ) ;

      $self->{localfile} = $files{ $target }{ $content };

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

    my $logger       = $self->{logger} ;
    my $content      = $self->{content} ;
    my $target       = $self->{target} ;
    my $short_entity = $self->{short_entity};
    my $runtype      = $self->{runtype} ;
    my %remotedirs ;

    if ( $target eq 'ILRISK' || $target eq 'SENTRY' ) {

       %remotedirs = ( ILRISK => {
                              MKTVAL  => '/l70',
                            },

                       SENTRY => {
                              MKTVAL  => '/ontw/data/wca/inbox/datamart',
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

    $self->{remotefile} = $self->{localfile} ; 

    return $self->{remotefile} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    my $target       = $self->{ target };

    if ( $target eq 'IBS' || $target eq 'EMS' ) {

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
    my %mvs_codes    = ( BR => 'B', CG => 'G', FR => 'F', LO => 'L', NL => 'N', HK => 'H', SH => 'A', SI => 'S', TW => 'T', AB => 'C', FP => 'P' );
    my %ems_codes    = ( BR => 'WL', CG => 'WH',  HK => 'VP', SH => 'WJ', SI => 'WM', FP => 'WN' );
    my %mvs_trigger ;

    if ( $target eq 'IBS' || $target eq 'EMS' ) {

       if ( $content eq 'VCR' || $content eq 'MKTVAL' || $content eq 'MIFID' ) {

         %mvs_trigger = ( IBS => { 
                                 VCR         => 'WF2AZ' . $env . 'U' . $mvs_codes{ $short_entity } ,
                                 MIFID       => 'WFAX3' . $env . 'U' . $mvs_codes{ $short_entity } ,
                               },
                          EMS => { 
                                 MKTVAL      => 'WF6' . $ems_codes{ $short_entity } . $env . 'UC' ,
                                 },
                        ); 

         $self->{remotetrigger} = $mvs_trigger{ $target }{ $content } ;

       }

    }

    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

    my ( $self ) = @_;

    my $content      = $self->{ content };
    my $target       = $self->{ target };

    if ( $target eq 'IBS' ) {

        my %files_width = ( IBS => {
                                   IRS     => '420' ,
                                   IRC     => '420' ,
                                   FRA     => '420' ,
                                   FRD     => '420' ,
                                   LOA     => '420' ,
                                   FXD     => '420' ,
                                   IRS_OLD => '440' ,
                                   OPT     => '100' ,
                                   FUT     => '420' ,
                                   FUTM    => '420' ,
                                   MIFID   => '300' ,
                                   VCR     => '160' ,
                                   },
                          ); 

        $self->{recordlength} = $files_width{ $target }{ $content } ;

    }


    if ( $content eq 'MKTVAL' ) {

         my $filewidth = 0 ;
         my $max_filewidth = 0 ;

         if ( ! -z $self->{localdir} . '/' . $self->{localfile} ) {

           open  (READLINE, $self->{localdir} . '/' . $self->{localfile} ) ;
              while (my $text = <READLINE> ) { 
              $filewidth = length($text) ;
              if ( $filewidth > $max_filewidth ) { $max_filewidth = $filewidth }
              }
           close (READLINE);

         }

         $self->{recordlength} = $max_filewidth ;

         #Overwrite
         $self->{recordlength} = '1000' ;


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

  if ( $target eq 'IBS' || $target eq 'EMS' ) {

       %keyfiles = ( IBS => {
                            IRS     => 'MVS_TEMPLATE.key' ,
                            IRC     => 'MVS_TEMPLATE.key' ,
                            FRA     => 'MVS_TEMPLATE.key' ,
                            OPT     => 'MVS_TEMPLATE.key' ,
                            FRD     => 'MVS_TEMPLATE.key',
                            VCR     => 'MVS_TEMPLATE_TRIGGER.key',
                            IRS_OLD => 'MVS_TEMPLATE.key' ,
                            LOA     => 'MVS_TEMPLATE.key' ,
                            FXD     => 'MVS_TEMPLATE.key' ,
                            FUT     => 'MVS_TEMPLATE.key' ,
                            FUTM    => 'MVS_TEMPLATE.key' ,
                            MIFID   => 'MVS_TEMPLATE_TRIGGER.key',
                         },

                  EMS => {
                            MKTVAL  => 'EMS_TEMPLATE_TRIGGER.key' ,
                         },

                    ) ;

      $self->{template_keyfile} = $keyfiles{ $target }{ $content };

  }

  if ( $target eq 'ILRISK' || $target eq 'SENTRY' ) {

       %keyfiles = ( ILRISK => {
                              MKTVAL  => 'ILRISK_MKTVAL_TEMPLATE.key',
                            },

                     SENTRY => {
                              MKTVAL  => 'SENTRY_MKTVAL_TEMPLATE.key',
                           },

                   ) ;

      $self->{template_keyfile} = $keyfiles{ $target }{ $content };

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
