package CDIRECT::cd_tc_eai;

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
    my $env          = get_env( $self->{pillar} );
    my %mx_dates     =  %{$self->{mx_dates}}  ;
    my %filenumbers  = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '07', SH => '09', SI => '15', TW => '13', CT => '00', FP => '29' );
    my $filenumber   = $filenumbers{ $short_entity };
    my %files ;

    my %runtype_files = ( MKTFXT    => { O => 'D' ,X => 'M' },
                          MKTLOA    => { O => 'D' ,X => 'M' },
                          MKTFRA    => { O => 'D' ,X => 'M' },
                          MKTIRS    => { O => 'D' ,X => 'M' },
                          MKTOPT    => { O => 'D' ,X => 'M' },
                          MKTFUT    => { O => 'D' ,X => 'M' },
                        );

    my $year           = substr( $mx_dates{ plcc_date } , 2, 2 ) ;
    my $month          = substr( $mx_dates{ plcc_date } , 4, 2 ) ;
    my $day            = substr( $mx_dates{ plcc_date } , 6, 2 ) ;

    if ( $runtype eq 'X' ) {

      $year           = substr( $mx_dates{ last_cal_day } , 2, 2 ) ;
      $month          = substr( $mx_dates{ last_cal_day } , 4, 2 ) ;
      $day            = substr( $mx_dates{ last_cal_day } , 6, 2 ) ;

    }

    my $rundate_mktloa = $day . $month . $year ;
    my $rundate_mktfxt = $day . $month . $year ;
    my $rundate_mktfra = $day . $month . $year ;
    my $rundate_mktirs = $day . $month . $year ;
    my $rundate_mktopt = $day . $month . $year ;
    my $rundate_mktfut = $day . $month . $year ;

    if ( $target eq 'ESB1' || $target eq 'ESB2' || $target eq 'ESB3' || $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3') {

       %files = ( ESB1 => {
                              IRS_GEN   => 'WMXkbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'WMXkbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'WMXNDMPortfolio_to_MxMLPortfolio.dat',
                             },
                  ESB2 => {
                              IRS_GEN   => 'WMXkbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'WMXkbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'WMXNDMPortfolio_to_MxMLPortfolio.dat',
                             },
                  ESB3 => {
                              IRS_GEN   => 'WMXkbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'WMXkbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'WMXNDMPortfolio_to_MxMLPortfolio.dat',
                             },

                  EGATE1 => {
                              IRS_GEN   => 'kbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'kbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'NDMPortfolio_to_MxMLPortfolio.dat',
                             },
                  EGATE2 => {
                              IRS_GEN   => 'kbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'kbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'NDMPortfolio_to_MxMLPortfolio.dat',
                             },
                  EGATE3 => {
                              IRS_GEN   => 'kbcGeneratorInfo_to_MxMLGeneratorInfo.dat',
                              DEP_GEN   => 'kbcGeneratorInfo_to_MxML_DEP_GeneratorInfo.dat',
                              PORTFOLIO => 'NDMPortfolio_to_MxMLPortfolio.dat',
                             },
                  ) ;
    }

    if ( $target eq 'ILRISK') {

       my $runtype_file = $runtype_files{ $content }{ $runtype } ;

       %files = ( ILRISK => {
                              MKTFRA  => 'D' . $env . '.WMX.V.MKTFRA.R0201.' . $runtype_file . '.XML.S' . $rundate_mktfra . '.C' . $filenumber,
                              MKTIRS  => 'D' . $env . '.WMX.V.MKTIRS.R0203.' . $runtype_file . '.XML.S' . $rundate_mktirs . '.C' . $filenumber,
                              MKTOPT  => 'D' . $env . '.WMX.V.MKTOPT.R0201.' . $runtype_file . '.XML.S' . $rundate_mktopt . '.C' . $filenumber,
                              MKTFXT  => 'D' . $env . '.WMX.V.MKTFXT.R0201.' . $runtype_file . '.XML.S' . $rundate_mktfxt . '.C' . $filenumber,
                              MKTLOA  => 'D' . $env . '.WMX.V.MKTLOA.R0203.' . $runtype_file . '.XML.S' . $rundate_mktloa . '.C' . $filenumber,
                              MKTFUT  => 'D' . $env . '.WMX.V.MKTFUT.R0201.' . $runtype_file . '.XML.S' . $rundate_mktfut . '.C' . $filenumber,
                            },

                  ) ;

    }

    $self->{localfile} = $files{ $target }{ $content };

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
    my %remotedirs ;

    if ( $target eq 'ESB1' || $target eq 'ESB2' || $target eq 'ESB3' ) {

       %remotedirs = ( ESB1 => {
                              IRS_GEN   => "/dyndatamaps",
                              DEP_GEN   => "/dyndatamaps",
                              PORTFOLIO => "/dyndatamaps",
                             },
                       ESB2 => {
                              IRS_GEN   => "/dyndatamaps",
                              DEP_GEN   => "/dyndatamaps",
                              PORTFOLIO => "/dyndatamaps",
                             },
                       ESB3 => {
                              IRS_GEN   => "/dyndatamaps",
                              DEP_GEN   => "/dyndatamaps",
                              PORTFOLIO => "/dyndatamaps",
                             },
                      ) ;
    }

    if ( $target eq 'EGATE1' || $target eq 'EGATE2' || $target eq 'EGATE3' || $target eq 'ILRISK' ) {

       %remotedirs = ( EGATE1 => {
                              IRS_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              DEP_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              PORTFOLIO => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                             },
                       EGATE2 => {
                              IRS_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              DEP_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              PORTFOLIO => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                             },
                       EGATE3 => {
                              IRS_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              DEP_GEN   => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                              PORTFOLIO => "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps",
                             },
                       ILRISK => {
                              MKTLOA  => '/l70',
                              MKTFXT  => '/l70',
                              MKTFRA  => '/l70',
                              MKTIRS  => '/l70',
                              MKTOPT  => '/l70',
                              MKTFUT  => '/l70',
                             },
                     ) ;

    }

    $self->{remotedir} = $remotedirs{ $target }{ $content } ;
    

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

  my $filewidth = 0 ;
  my $max_filewidth = 0 ;
         
  if ( ! -z $self->{localdir} . '/' . $self->{localfile} ) {

     open (READLINE, $self->{localdir} . '/' . $self->{localfile} ) ;
        while (my $text = <READLINE> ) {
            $filewidth = length($text) ;
            if ( $filewidth > $max_filewidth ) { $max_filewidth = $filewidth }
        }
     close (READLINE);

  }

  $self->{recordlength} = $filewidth ;

  return $self->{recordlength} ;

}

#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  my $target       = $self->{ target };

  if ( $target eq 'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) { $self->{template_keyfile} = 'EGATE_DATAMAPS_TEMPLATE.key' ; } ;
  if ( $target eq 'ESB1' || $target eq  'ESB2' || $target eq  'ESB3' ) { $self->{template_keyfile} = 'ESB_DATAMAPS_TEMPLATE.key' ; } ;
  if ( $target eq 'ILRISK' ) { $self->{template_keyfile} = 'ILRISK_TEMPLATE.key' ; } ; 


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
