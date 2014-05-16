package CDIRECT::cd_mo_report_abm;

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

    if ( $content eq "abhost_tr" ) { $self->{audit} = 'N' ; } ;

    return $self->{audit} ;

}


#----------------#
sub get_localdir {
#----------------#

    my ( $self ) = @_;

    my $content      = $self->{content} ;

    my $localdir = $self->{config}->KBC_TRANSFERDIR ;

    my %sourcedirs  = (  abhost_tr      => "abhost_tr",
                         reconsiliation => "reconsiliation",
                         intrareconsil  => "reconsiliation",
                         request_quote  => "request_quote",
                         risk_reporting => "risk_reporting" );

    $self->{localdir} = $localdir . '/out/' . $sourcedirs{ $content };

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

    my %sourcefiles  = ( abhost_tr      => "*.csv",
                         reconsiliation => "*.csv",
                         intrareconsil  => "*.csv",
                         request_quote  => "reqquote.txt",
                         risk_reporting => "*.asc" );

    if ( $content eq 'intrareconsil' ) {

       my @filenames    = glob( $self->{localdir} . '/' . $sourcefiles{ $content } );

       if ( ! @filenames ) {

          $logger->info ("CDIRECT INFO : no files found to send !!!");
          print "CDIRECT INFO : no files found to send !!! \n" ;
          exit 0 ;

       }

    }


    $self->{localfile} = $sourcefiles{ $content }; 


    return $self->{localfile} ;

}


#-----------------#
sub get_remotedir {
#-----------------#

    my ( $self ) = @_;

    my $content  = $self->{content} ;
    my $pillar   = $self->{pillar}  ;

    my %remotedirs  = ( O => {
                             abhost_tr => "/ontw/data/d96/receive",
                             reconsiliation => "/ontw/data/d96/receive/",
                             intrareconsil => "/ontw/data/d96/receive/",
                             risk_reporting => "D:\\DNDM\\EntityTransfer\\CZ\\Murex\\",
                             request_quote  => "/ontw/etc/wda/Bloomberg/",
                             },
                        A => {
                             abhost_tr => "/ontw/data/d96/receive",
                             reconsiliation => "/ontw/data/d96/receive/",
                             intrareconsil => "/ontw/data/d96/receive/",
                             risk_reporting => "D:\\DNDM\\EntityTransfer\\AB\\Murex\\",
                             request_quote  => "/ontw/etc/wda/Bloomberg/",
                             },
                        P => {
                             abhost_tr => "/ontw/data/d96/receive",
                             reconsiliation => "/ontw/data/d96/receive/",
                             intrareconsil => "/ontw/data/d96/receive/",
                             risk_reporting => "D:\\DNDM\\EntityTransfer\\AB\\Murex\\",
                             request_quote  => "/ontw/etc/wda/Bloomberg/",
                             },
                     );

    $self->{remotedir} = $remotedirs { $pillar }{ $content };


    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $content  = $self->{content} ;

    my %remotefiles = ( abhost_tr => "&W1.csv",
                        reconsiliation => "&W1.csv",
                        intrareconsil  => "&W1.csv",
                        request_quote  => "FXM_request.csv",
                        risk_reporting => "&W1.asc" );

    $self->{remotefile} = $remotefiles { $content };


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

  return $self->{recordlength} ;

}

#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  my $target   = $self->{ target };

  my %template_keyfiles = (  ABSOLUT1 => "ABSOLUT_TEMPLATE.key",
                             ABSOLUT2 => "ABSOLUT_TEMPLATE.key",
                             ERIS     => "ERIS_TEMPLATE.key",
                             FAME     => "FAME_TEMPLATE.key" ) ;

  $self->{template_keyfile} =  $template_keyfiles { $target } ;


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

1;
