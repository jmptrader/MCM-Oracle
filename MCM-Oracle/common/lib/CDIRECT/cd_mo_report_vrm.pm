package CDIRECT::cd_mo_report_vrm;

use CDIRECT::cd_cdirect;

our @ISA = qw(CDIRECT::cd_cdirect) ;

use warnings;
use strict;

use POSIX qw(strftime);


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

    my $logger        = $self->{logger} ;
    my $content       = $self->{content} ;
    my $target        = $self->{target} ;
    my $short_entity  = $self->{short_entity};
    my $runtype       = $self->{runtype} ;
    my %mx_dates      = %{$self->{mx_dates}}  ;
    my $env           = get_env( $self->{pillar} );
    my %filenumbers   = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '07', SH => '09', SI => '15', TW => '13', CT => '00', FP => '29' );
    my $filenumber    = $filenumbers{ $short_entity };
    my %runtype_files = (  O => '1', 1 => '2', V => '3', X => '4' ) ;
    my $runtype_file  = $runtype_files{ $runtype } ;

    my $rundate_ems        = substr( $mx_dates{ cal_date } ,2 ,6 ) ;
    my $rundate_esales     = substr( $mx_dates{ plcc_date }, 2 )  ;
    my $rundate_structuren = substr( $mx_dates{ sys_date }, 2 )  ;
    my %files ;

    print "rundate_ems = $rundate_ems \n" ;
    print "env = $env \n" ;
   
    if ( $target eq 'EMS' || $target eq 'ESALES' || 'DATAKOEPEL' ) {

       %files = ( EMS        => {
                                VARTPF  => 'WF6' . $env . 'BICT.EXTN.VARTPF.D' . $rundate_ems ,
                                },
                  ESALES     => {
                                ESALES => 'QZ3' . $env . 'E000.EXTN.MDMTRX.D' . $runtype_file . '.C' . $filenumber . '.D' . $rundate_esales ,
                                },
                  DATAKOEPEL => {
                                RTBLOCK => "RTBLOCK*.csv",
                                },
                );

       $self->{localfile} = $files{ $target }{ $content };

    }

    if ( $target eq 'MVS' ) {

       %files = ( MVS        => {
                                STRUCT_MTM => 'QZ3' . $env . 'B000.EXTN.VRM.STRUCT.D' . $rundate_structuren ,
                                },

                 );

       $self->{localfile} = $files{ $target }{ $content };

    }

    if ( $target eq 'EMS' || $target eq 'ESALES' || $target eq 'MVS' ) {

         if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
            print "Could not open file $self->{localdir}/$self->{localfile} !!! \n" ;
            $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
         }
    }

    return $self->{localfile} ;

}


#-----------------#
sub get_remotedir {
#-----------------#

    my ( $self ) = @_;

    my $target       = $self->{target} ;
    my $content      = $self->{content} ;
    my $pillar       = $self->{pillar} ;
    my %remotedirs ;


    if ( $target eq 'DATAKOEPEL') {

       %remotedirs  = ( O => { 
                             RTBLOCK => $self->{remotedir},
                             },
                        A => {
                             RTBLOCK => "\\\\adfs\\functioneel\\Datakoepel\\condirect\\vrm\\ACC",
                             },
                        P => {
                             RTBLOCK => "\\\\adfs\\functioneel\\Datakoepel\\condirect\\VRM\\PRD",
                             },
                       );

       $self->{remotedir} = $remotedirs{ $pillar }{ $content };

    }

    return $self->{remotedir} ;

}

#------------------#
sub get_remotefile {
#------------------#

    my ( $self ) = @_;

    my $target   = $self->{ target };

    $self->{remotefile} = $self->{localfile} ;

    if ( $target eq 'DATAKOEPEL') {

       $self->{remotefile} = "RTBLOCK&W1.csv";

    }

    return $self->{remotefile} ;

}

#------------------#
sub get_remotenode {
#------------------#

    my ( $self ) = @_;

    my $target        = $self->{target} ;
    my $pillar        = $self->{pillar} ;

    my %remote_nodes = ( O => {
                             DATAKOEPEL => "NO.SERVER",
                             EMS        => "NO.SERVER",
                             ESALES     => "NO.SERVER",
                             MVS        => "NO.SERVER",
                             },
                        A => {
                             DATAKOEPEL => "PRMBOP1",
                             EMS        => "ACP.SSKC",
                             ESALES     => "ACP.SSKC",
                             MVS        => "ACP.SSKC",
                             },
                        P => {
                             DATAKOEPEL => "PRMBOP1",
                             EMS        => "MVS.SSPC",
                             ESALES     => "MVS.SSPC",
                             MVS        => "MVS.SSPC",
                             },
                       );



    $self->{remotenode} = $remote_nodes{ $pillar }{ $target };

    return $self->{remotenode} ;

}


#-----------------#
sub get_remotejob {
#-----------------#

    my ( $self ) = @_;

    my $target   = $self->{ target };

    if ( $target eq 'EMS' || $target eq 'ESALES' || $target eq 'MVS' ) {

       my %remote_jobs = ( O => "CERATST", A => "CERAK", P => "CERA" ) ;

       $self->{remotejob} = $remote_jobs { $self->{pillar} } ;

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

    if ( $target eq 'EMS' ) {

       $self->{remotetrigger} = "WF6WA${env}UC";

    }

    if ( $target eq 'MVS'  && $content eq 'STRUCT_MTM') {

        $self->{remotetrigger} = "QZ303${env}U1";

    }

    return $self->{remotetrigger} ;


}

#--------------------#
sub get_recordlength {
#--------------------#

  my ( $self ) = @_;

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

         if ( $self->{target} eq 'MVS' && $self->{content} eq 'STRUCT_MTM' ) { $self->{recordlength} = '1500' ; } ;

  return $self->{recordlength} ;

}

#-----------------------#
sub get_templatekeyfile {
#-----------------------#

  my ( $self ) = @_;

  if ( $self->{target} eq 'EMS' ) { $self->{template_keyfile} = 'MVS_TEMPLATE_TRIGGER.key' ; } ;

  if ( $self->{target} eq 'ESALES' ) { $self->{template_keyfile} = 'MVS_TEMPLATE.key' ; } ;

  if ( $self->{target} eq 'MVS'  && $self->{content} eq 'STRUCT_MTM') { $self->{template_keyfile} = 'MVS_TEMPLATE_NORCL.key' ; } ;

  if ( $self->{target} eq 'DATAKOEPEL' ) { $self->{template_keyfile} = 'DATAKOEPEL_TEMPLATE.key' ; } ;

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
