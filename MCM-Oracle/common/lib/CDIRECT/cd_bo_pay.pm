package CDIRECT::cd_bo_pay;

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
    my %file_branch_codes = ( BR => 'KBC', CG => 'CBC') ;
    my $file_branch_code  = $file_branch_codes{ $short_entity };
    my %files ;

    my $rundate_baf    = substr( $mx_dates{ plcc_date }, 2 ) ;


    if ( $target eq 'WHT' ) {


       %files = ( WHT => {
                            BAF  => 'CPR' . $env . 'B0' . $filenumber . '.EXTN.PIBBWT.DTMRT.IREG.D' . $rundate_baf ,
                         },
                );

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

    my $target   = $self->{ target };

    if ( $target eq 'WHT' ) {

      my %remote_jobs = ( O => 'CERATST', A => 'CERAK', P => 'CERA' ) ;

      $self->{remotejob} = $remote_jobs { $self->{pillar} } ;

    }


    return $self->{remotejob} ;

}


#---------------------#
sub get_remotetrigger {
#---------------------#

    my ( $self ) = @_;

    my $short_entity       = $self->{ short_entity };
    my $content      = $self->{ content };
    my $target       = $self->{ target };
    my $env          = get_env( $self->{pillar} );
    my %trigger_wht  = ( BR => '1', CG => '2', FR => '0', LO => '3', NL => '0', HK => '6', SH => '5', SI => '4', TW => '0', CT => '0', FP => '7' );
    my $trigger_wht_code = $trigger_wht{ $short_entity } ;
    my %mvs_trigger ;

    if ( $target eq 'WHT'  ) {

       %mvs_trigger = ( WHT => {
                               BAF =>  'CPRA0' . $env . 'U' . $trigger_wht_code ,
                               },
                      );

       $self->{remotetrigger} = $mvs_trigger{ $target }{ $content } ;

    }


    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

  my ( $self ) = @_;

  my $content      = $self->{ content };
  my $target       = $self->{ target };

  if ( $target eq 'WHT' ) {

     my %files_width = ( WHT => {
                                   BAF     => '329' ,
                                   },
                          );

     $self->{recordlength} = $files_width{ $target }{ $content } ;

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

  if ( $target eq 'WHT' ) {

       if ( $content eq 'BAF' ) { $self->{template_keyfile} =  'MVS_TEMPLATE_TRIGGER.key' ; } ;

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
