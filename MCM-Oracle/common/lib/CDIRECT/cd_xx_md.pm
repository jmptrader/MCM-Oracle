package CDIRECT::cd_xx_md;

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

    my %localfiles   = ( IEAINF001   => "trmkr01.csv",
                         IEAINF003   => "trmk03.csv",
                         IEAINF004   => "trmk04.csv",
                         IEAINF006   => "trmkr06.csv",
                         IEAINF007   => "trmkr07.csv",
                         IEAINF008   => "trmkr08.csv",
                         IEAINF016   => "trmkr016.csv",
                         FDEKEYMX    => "trmkr01f.csv",
                         IRMDNFFDE1  => "fde_req_curves.csv",
                         IRMDNFFDE3  => "fde_req_bonds.csv",
                         IRMDNFFDE4  => "fde_req_futures.csv",
                         IRMDNFFDE7  => "fde_req_spots.csv",
                         IRMDNFFDE16 => "fde_req_options.csv");
     
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

    if ( $target eq 'FDE' ) { $self->{remotedir} = '/ontw/data/FDE/fdeio/in/infisu' ; } ;

    if ( $target eq 'FAME' && $content eq 'IEAINF016' ) { $self->{remotedir} = '/ontw/etc/wda/Bloomberg' ; } ;

    if ( $target eq  'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) { $self->{remotedir} = "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps" ; } ;    

    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $date_time    = calendardate () ;

    my $content      = $self->{ content };

    my %remotefiles     = ( IEAINF001 => "trmkr01.csv",
                            IEAINF003 => "trmk03.csv",
                            IEAINF004 => "trmk04.csv",
                            IEAINF006 => "trmkr06.csv",
                            IEAINF007 => "trmkr07.csv",
                            IEAINF008 => "trmkr08.csv",
                            IEAINF016 => "trmkr016.csv",
                            FDEKEYMX  => "trmkr01f.csv",
                            IRMDNFFDE1 => "MXC_Infisu_${date_time}001.txt",
                            IRMDNFFDE3 => "MXB_Infisu_${date_time}003.txt",
                            IRMDNFFDE4 => "MXF_Infisu_${date_time}004.txt",
                            IRMDNFFDE7 => "MXS_Infisu_${date_time}007.txt",
                            IRMDNFFDE16 => "MXD_Infisu_${date_time}016.txt");

    $self->{remotefile} = $remotefiles{ $content };

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

  if ( ! -z $self->{localdir} . '/' . $self->{localfile} ) {

    open (READLINE, $self->{localdir} . '/' . $self->{localfile} ) ;
      my $text = <READLINE> ;
      $filewidth = length($text) ;
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

  my %template_keyfiles = (  EGATE1 => "EGATE_DATAMAPS_TEMPLATE.key",
                             EGATE2 => "EGATE_DATAMAPS_TEMPLATE.key",
                             EGATE3 => "EGATE_DATAMAPS_TEMPLATE.key",
                             FAME   => "FAME_TEMPLATE.key",
                             FDE    => "FDE_TEMPLATE.key") ;

  $self->{template_keyfile} = $template_keyfiles { $target } ; ;


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

#----------------#
sub calendardate {
#----------------#
    my ($sec,$min,$hour,$day, $month, $year) = ( localtime( time() ) )[0..5];
    return sprintf "%04s%02s%02s%02s%02s%02s", $year + 1900, ++$month, $day,$hour,$min,$sec;
}


1;
