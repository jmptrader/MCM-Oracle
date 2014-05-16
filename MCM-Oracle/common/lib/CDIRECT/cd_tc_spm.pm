package CDIRECT::cd_tc_spm;

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

    my $date         = calendardate () ;
     
    $self->{localfile} = 'RESULT' . $date . '.csv' ;


    if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
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

    if ( $target eq  'EGATE1' || $target eq  'EGATE2' || $target eq  'EGATE3' ) { $self->{remotedir} = "/opt/egate/${segment}/egate/client/monk_scripts/collabs/datamaps" ; } ;    

    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    $self->{remotefile} = $self->{localfile} ; 

    return $self->{remotefile} ;

}

#------------------#
sub get_remotenode {
#------------------#

   my ( $self ) = @_;

   my %remote_nodes = ( O => "ONT.SSTC",
                        A => "ACP.SSKC",
                        P => "MVS.SSPC" );



    $self->{remotenode} = $remote_nodes { $self->{pillar}  ;

    return $self->{remotenode} ;

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

  $self->{template_keyfile} = 'EGATE_DATAMAPS_TEMPLATE.key' ;


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
    return sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;
}


1;
