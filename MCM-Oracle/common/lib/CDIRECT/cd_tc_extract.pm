package CDIRECT::cd_tc_extract;

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

    my $content      = $self->{content} ;

    return $self->{audit} ;

}


#----------------#
sub get_localdir {
#----------------#

    my ( $self ) = @_;

    my $target       = $self->{target} ;

    my $localdir = $self->{config}->KBC_TRANSFERDIR ;

    if ( $target eq 'ALGO' || $target eq 'SENTRY') {

       $localdir = $self->{config}->KBC_CDDIR ;

    }
    

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

    my %localfiles   = ( ALGO             => "ALG.xml",
                         SENTRY           => "COL.xml",
                         EMS              => "EMS.xml",
                         IBS_TREASURY     => "TRS.xml",
                         MXG3             => "MDM.xml",
                         IBS_EXCHANGE     => "EXP.xml",
                         DEAD             => "DEAD.xml",
                         MIGRATION        => "MIG.csv",
                         PREMIGRATION     => "PREMIG.csv",
                         MIGRAT_FILE_FXMM => "MIGRAT_FILE_FXMM_$short_entity.CSV" ) ; 
     
    $self->{localfile} = $localfiles { $content };


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
    my $segment      = $self->{segment} ;
    my $pillar       = $self->{pillar} ;

    if ( $target eq  'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) {

        my %remotedirs  = ( ALGO         => "RSKW",
                            SENTRY       => "SENTRY",
                            EMS          => "EMS",
                            IBS_TREASURY => "IBS_Treasury",
                            MXG3         => "MXG3",
                            IBS_EXCHANGE => "FXMM",
                            DEAD         => "FXMM" ) ;

        my $remotedir = $remotedirs { $content };

        $self->{remotedir} = "/var/data/KBCB_MARKETS/$remotedir/ft" ;    

    }

    if ( $target eq  'ESB' ) {

        if ( $content eq 'ALGO' ) {

          $self->{remotedir} = "/mgmt/data/esb/initload/mkt/murextorskw/pub/wmx/murex/ft" ;
   
        }

        if ( $content eq 'SENTRY' ) {

          $self->{remotedir} = "/mgmt/data/esb/initload/mkt/murextosentry/pub/wmx/murex/ft" ;

        }

        if ( $content eq 'EMS' ) {

          $self->{remotedir} = "/mgmt/data/esb/initload/mkt/murextoems/pub/wmx/murex/ft" ;

        }

        if ( $content eq 'IBS_TREASURY' ) {

          $self->{remotedir} = "/mgmt/data/esb/initload/mkt/murextoibstres/pub/wmx/murex/ft" ;

        }

        if ( $content eq 'MXG3' ) {

          $self->{remotedir} = "/mgmt/data/esb/initload/mkt/murextomurexdatamart/pub/wmx/murex/ft/" ;

        }

    }

    if ( $target eq 'ALGO' ) {

           my %remotedirs  = ( O => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wal/delivery/initload",

                                     },
				A => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wal/delivery/initload", 

                                     },
				P => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wal/delivery/initload", 

                                     }, 
                     );

           $self->{remotedir} = $remotedirs { $pillar }{ $content };

    }

    if ( $target eq 'SENTRY' ) {

           my %remotedirs  = ( O => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wca/inbox/initload", 

                                     },
                                A => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wca/inbox/initload", 

                                     },
                                P => {

                                     MIGRAT_FILE_FXMM => "/ontw/data/wca/inbox/initload", 

                                     }, 
                     );

           $self->{remotedir} = $remotedirs { $pillar }{ $content };

    }



    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $logger       = $self->{logger} ;
    my $content      = $self->{content} ;
    my $target       = $self->{target} ;
    my $short_entity = $self->{short_entity};
    my $runtype      = $self->{runtype} ;
    my $env          = get_env( $self->{pillar} );
    my %rundates     = get_rundate() ;
    my $rundate      = $rundates{ date_yymmdd } ;


    if ( $target eq  'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) {

       my %remotefiles  = ( ALGO          => "INITLOAD_RSKW.dat",
                            SENTRY        => "INITLOAD_SENTRY.dat",
                            EMS           => "INITLOAD_EMS.dat",
                            IBS_TREASURY  => "INITLOAD_IBS_TREASURY_$short_entity.dat",
                            MXG3          => "INITLOAD_MXG3.dat",
                            IBS_EXCHANGE  => "INITLOAD_IBS_EXCHANGE_$short_entity.dat" ,
                            DEAD          => "INITLOAD_IBS_EXCHANGE.dat" ) ;

       $self->{remotefile} = $remotefiles { $content };

    }

    if ( $target eq  'ESB' ) {

       my %remotefiles  = ( ALGO          => "INITLOAD_RSKW.dat",
                            SENTRY        => "INITLOAD_SENTRY.dat",
                            EMS           => "INITLOAD_EMS.dat",
                            IBS_TREASURY  => "INITLOAD_IBS_TREASURY_$short_entity.dat",
                            MXG3          => "INITLOAD_MUREXDATAMART.dat",
                            IBS_EXCHANGE  => "INITLOAD_IBS_EXCHANGE.dat" ,
                            DEAD          => "INITLOAD_IBS_EXCHANGE.dat" ) ;

       $self->{remotefile} = $remotefiles { $content };

    }


    if ( $target eq  'IBS' ) {

       my %remotefiles  = ( MIGRATION     => "WF2" . "$env" . "BI" . "$short_entity" . ".EXTN.MIGRAT.MUREX.D" . "$rundate" ,
                            PREMIGRATION  => "WF2" . "$env" . "BI" . "$short_entity" . ".EXTN.MIGRAT.MUREX.D" . "$rundate" ) ;

       $self->{remotefile} = $remotefiles { $content };

    }

    if ( $target eq  'ALGO' ) {

       my %remotefiles  = ( MIGRAT_FILE_FXMM => "migrationfile" ) ;

       $self->{remotefile} = $remotefiles { $content };

    }


    if ( $target eq  'SENTRY' ) {

       my %remotefiles  = ( MIGRAT_FILE_FXMM => "migratiefile" ) ;

       $self->{remotefile} = $remotefiles { $content };

    }



    return $self->{remotefile} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    return $self->{remotejob} ;

}


#---------------------#
sub get_remotetrigger {
#---------------------#

    my ( $self ) = @_;

    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

  my ( $self ) = @_;

  if ( $self->{target} eq 'IBS' ) {

     $self->{recordlength} = '120' ;

  }

  return $self->{recordlength} ;

}

#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  my $target       = $self->{ target };

  if ( $self->{target} eq 'IBS' ) {

    $self->{template_keyfile} = 'MVS_EXTRACTION_TEMPLATE.key' ;

  } ;

  if ( $target eq  'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) {

    $self->{template_keyfile} = 'EGATE_EXTRACTION_TEMPLATE.key' ;

  }

  if ( $self->{target} eq 'ALGO' ) {

    $self->{template_keyfile} = 'ALGO_EXTRACTION_TEMPLATE.key' ;

  } ;

  if ( $self->{target} eq 'SENTRY' ) {

    $self->{template_keyfile} = 'SENTRY_EXTRACTION_TEMPLATE.key' ;

  } ;

  if ( $self->{target} eq 'ESB' ) {

    $self->{template_keyfile} = 'ESB_EXTRACTION_TEMPLATE.key' ;

  } ;


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

#---------------#
sub get_rundate {
#---------------#

    # get day month year
    #my ( $day, $month, $year ) = ( localtime(time) )[3, 4 ,5];
    my ($sec,$min,$hour,$day, $month, $year) = ( localtime( time() ) )[0..5];

    # put year in correct format
    $year += 1900;

    # month in range from [0-11] => add 1
    $month += 1;

    my $date_yymmdd = sprintf( "%02d%02d%02d", $year % 100, $month, $day );
    my $date_yymm   = sprintf( "%02d%02d", $year % 100, $month );
    my $date_ddmmyy = sprintf( "%02d%02d%02d", $day, $month, $year % 100 );
    my $date_mmyy   = sprintf( "%02d%02d", $month, $year % 100 );

    my %rundates = ( date_yymmdd => $date_yymmdd, date_yymm => $date_yymm, date_ddmmyy => $date_ddmmyy, date_mmyy => $date_mmyy );
    return %rundates;

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
