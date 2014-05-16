package CDIRECT::cd_fo_absolut;

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

    return $self->{send} ;

}


#--------------------#
sub get_audit        {
#--------------------#

    my ( $self ) = @_;

    my $content      = $self->{content} ;

    if ( $content eq "export" ) { $self->{audit} = 'N' ; } ;

    return $self->{audit} ;

}


#----------------#
sub get_localdir {
#----------------#

    my ( $self ) = @_;

    my $content      = $self->{content} ;

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

    my @filenames    = glob( $self->{localdir} . '/' . "*xml" );
    my @lockfiles    = glob( $self->{localdir} . '/' . "*xml_lock" );

    if ( ! @filenames && ! @lockfiles ) {


        $logger->info ("CDIRECT INFO : no files found to send !!!");
        print "CDIRECT INFO : no files found to send !!! \n" ;
        exit 0 ;

    }

    sleep 5 ;
    foreach my $filename (@filenames) {

        move ( $filename , $filename . '_lock' ) ;
    }

    my %sourcefiles  = ( export      => "*.xml_lock" ) ;

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
                             export => "/ontw/data/d96/jboss/in",
                             },
                        A => {
                             export => "/ontw/data/d96/jboss/in",
                             },
                        P => {
                             export => "/ontw/data/d96/jboss/in",
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

    my %remotefiles = ( export => "&W1.xml" );

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
                             ABSOLUT2 => "ABSOLUT_TEMPLATE.key",);

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
