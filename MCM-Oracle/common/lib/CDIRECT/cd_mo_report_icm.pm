package CDIRECT::cd_mo_report_icm;

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

    my %dates        = $self->get_dates();

    ##Short entity exception for ABSOLUT bank, the short entity used for sending to ICRAP is CT iso AB
   
    if ( $short_entity eq "AB" ) {
        $short_entity = "CT";
    }


    my $env          = get_env( $self->{pillar} );

    my %IC_files_daily   = ( PL     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL72.D' . $dates{ filename_d },
                             TR     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL74.D' . $dates{ filename_d },
                             UDF    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL75.D' . $dates{ filename_d },
                             CP     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL76.D' . $dates{ filename_d },
                             PF     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL77.D' . $dates{ filename_d },
                             CS     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL78.D' . $dates{ filename_d },
                             POS    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL81.D' . $dates{ filename_d },
                             POSD   => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL82.D' . $dates{ filename_d },
                             IRC    => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD01A.D' . $dates{ filename_d },  
                             SPR    => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD02A.D' . $dates{ filename_d },
                             PRI    => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD03A.D' . $dates{ filename_d },
                             GMP    => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD04A.D' . $dates{ filename_d },
                             IRCIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD01A.RA13',
                             SPRIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD02A.RA13',
                             PRIIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD03A.RA13',
                             GMPIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD04A.RA13',
                             DET    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL87.D' . $dates{ filename_d },
                             STRAT  => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL93.D' . $dates{ filename_d },
                             TPF    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL98.D' . $dates{ filename_d },
                             TPFFIX => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DIL99.D' . $dates{ filename_d },
                             AUD    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DILB2.D' . $dates{ filename_d },
                             AUDVL  => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2DILB3.D' . $dates{ filename_d },
                             MKTOPT => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2P021.D'  . $dates{ filename_d },
                             PAY    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2P022.D'  . $dates{ filename_d } );

    my %IC_files_monthly = ( PL     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL10.M' . $dates{ filename_m },
                             TR     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL12.M' . $dates{ filename_m },
                             UDF    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL13.M' . $dates{ filename_m },
                             CS     => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL14.M' . $dates{ filename_m },
                             POS    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL19.M' . $dates{ filename_m },
                             POSD   => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL20.M' . $dates{ filename_m },
                             IRC    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.TMXMD01M.M' . $dates{ filename_m },
                             SPR    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.TMXMD02M.M' . $dates{ filename_m },
                             PRI    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.TMXMD03M.M' . $dates{ filename_m },
                             GMP    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.TMXMD04M.M' . $dates{ filename_m },
                             IRCIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD01M.RA13',    
                             SPRIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD02M.RA13',
                             PRIIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD03M.RA13',
                             GMPIL  => 'UMX'. $env . 'BI' . $short_entity . '.EXTN.TMXMD04M.RA13',
                             DET    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL25.M' . $dates{ filename_m },
                             STRAT  => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL27.M' . $dates{ filename_m },
                             TPF    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL28.M' . $dates{ filename_m },
                             TPFFIX => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2MIL29.M' . $dates{ filename_m },
                             MKTOPT => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2P021M.M' . $dates{ filename_m },
                             PAY    => 'UF2'. $env . 'BI' . $short_entity . '.EXTN.F2P022M.M' . $dates{ filename_m } );


    # retrieve the correct filename
    my $filename;
        if ( $runtype eq 'X' ) {
          $filename = $IC_files_monthly{ $content };
        }
        else {
          $filename = $IC_files_daily{ $content };
        }


    $self->{localfile} = $filename ;

    #### TEMP SOLUTION FOR FR/NL

    if ( $short_entity eq "NL" || $short_entity eq "FR" ) {

       if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
          print "File not found, sending dummy file ... \n";
          $logger->info('Sending dummy file ... ') ;
          open (OUTPUTFILE, ">$self->{localdir}/$self->{localfile}") || $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
          close (OUTPUTFILE) || $logger->logdie ("Can't close $!");
       }
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

    my %remote_jobs = ( O => "CERATST", A => "CERAK", P => "CERA" ) ;

    $self->{remotejob} = $remote_jobs { $self->{pillar} } ;

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
    my %mvs_codes    = ( BR => 'B', CG => 'G', FR => 'F', LO => 'L', NL => 'N', HK => 'H', SH => 'A', SI => 'S', TW => 'T', CT => 'C', FP => 'P' );

    if ( $short_entity eq "AB" ) {
        $short_entity = "CT";
    }

    my %IC_trigger_daily  = (   PL     => 'UF23U' . $env . 'U' . $mvs_codes{ $short_entity },
                                TR     => 'UF23W' . $env . 'U' . $mvs_codes{ $short_entity },
                                UDF    => 'UF23X' . $env . 'U' . $mvs_codes{ $short_entity },
                                CP     => 'UF23Y' . $env . 'U' . $mvs_codes{ $short_entity },
                                PF     => 'UF23Z' . $env . 'U' . $mvs_codes{ $short_entity },
                                CS     => 'UF240' . $env . 'U' . $mvs_codes{ $short_entity },
                                POS    => 'UF243' . $env . 'U' . $mvs_codes{ $short_entity },
                                POSD   => 'UF244' . $env . 'U' . $mvs_codes{ $short_entity },
                                IRC    => 'UMX1A' . $env . 'U' . $mvs_codes{ $short_entity },
                                SPR    => 'UMX2A' . $env . 'U' . $mvs_codes{ $short_entity },
                                PRI    => 'UMX3A' . $env . 'U' . $mvs_codes{ $short_entity },
                                GMP    => 'UMX4A' . $env . 'U' . $mvs_codes{ $short_entity },
                                DET    => 'UF249' . $env . 'U' . $mvs_codes{ $short_entity },
                                STRAT  => 'UF2C9' . $env . 'U' . $mvs_codes{ $short_entity },
                                TPF    => 'UF2CZ' . $env . 'U' . $mvs_codes{ $short_entity },
                                TPFFIX => 'UF2D0' . $env . 'U' . $mvs_codes{ $short_entity },
                                AUD    => 'UF2DR' . $env . 'U' . $mvs_codes{ $short_entity },
                                AUDVL  => 'UF2DS' . $env . 'U' . $mvs_codes{ $short_entity },
                                PAY    => 'UF2FB' . $env . 'U' . $mvs_codes{ $short_entity },
                                MKTOPT => 'UF2FA' . $env . 'U' . $mvs_codes{ $short_entity } );


    my %IC_trigger_monthly = (  PL     => 'UF252' . $env . 'U' . $mvs_codes{ $short_entity },
                                TR     => 'UF254' . $env . 'U' . $mvs_codes{ $short_entity },
                                UDF    => 'UF255' . $env . 'U' . $mvs_codes{ $short_entity },
                                CS     => 'UF256' . $env . 'U' . $mvs_codes{ $short_entity },
                                POS    => 'UF25B' . $env . 'U' . $mvs_codes{ $short_entity },
                                POSD   => 'UF25C' . $env . 'U' . $mvs_codes{ $short_entity },
                                IRC    => 'UMX1M' . $env . 'U' . $mvs_codes{ $short_entity },
                                SPR    => 'UMX2M' . $env . 'U' . $mvs_codes{ $short_entity },
                                PRI    => 'UMX3M' . $env . 'U' . $mvs_codes{ $short_entity },
                                GMP    => 'UMX4M' . $env . 'U' . $mvs_codes{ $short_entity },
                                DET    => 'UF25H' . $env . 'U' . $mvs_codes{ $short_entity },
                                STRAT  => 'UF2CA' . $env . 'U' . $mvs_codes{ $short_entity },
                                TPF    => 'UF2D1' . $env . 'U' . $mvs_codes{ $short_entity },
                                TPFFIX => 'UF2D2' . $env . 'U' . $mvs_codes{ $short_entity },
                                PAY    => 'UF2FD' . $env . 'U' . $mvs_codes{ $short_entity },
                                MKTOPT => 'UF2FC' . $env . 'U' . $mvs_codes{ $short_entity } );

    # retrieve the correct trigger

    if ( $runtype eq 'X' ) {
          $trigger = $IC_trigger_monthly{ $content };
    } else {
          $trigger = $IC_trigger_daily{ $content };
    }

    $self->{remotetrigger} = $trigger ;

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

  if ( $self->{target} eq 'IC' ) {

     $self->{template_keyfile} = 'MVS_TEMPLATE_TRIGGER.key' ;

  }

  if ( $self->{target} eq 'ICIL' ) {

     $self->{template_keyfile} = 'MVS_TEMPLATE.key' ;

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

    
#-------------#
sub get_dates {
#-------------#

    my ( $self ) = @_;

    my $logger      = $self->{logger} ;
    my $db_audit    = $self->{db_audit} ;
    my $config      = $self->{config} ;
    my $short_entity = $self->{short_entity};
    my $glob_entity  = $self->{glob_entity};

    my $path ;

    ###Solution for sending FR/NL files
    if ( $short_entity eq "NL" || $short_entity eq "FR" ) {
       $path = $config->KBC_RUNDIR . '/ictoday_BR' . '.prn' ;
    } else {
       $path = $config->KBC_RUNDIR . '/ictoday_' . $glob_entity . '.prn';
    }

    my $report_dates = Mx::Report->new (logger => $logger, db_audit => $db_audit, type => 'file', path => $path, label => 'DATES');

    # get dates from file
    #~~~~~~~~~~~~~~~~~~~~
    unless ( $report_dates->open( mode => 'read' ) ) {
        $logger->logdie('Date file [' . $report_dates->path . '] not found');
    };
    my $record = $report_dates->get_record();
    my @dates  = split (/,/, $record);
    $report_dates->close();

    # calculate previous month ( file format: YYYY.MM )
    #~~~~~~~~~~~~~~~~~~~~~~~~~------------------------
    my @date = split(/\./, $dates[4]);

    my $year        = $date[0];
    my $prev_month  = $date[1] - 1;

    if ( $prev_month == 0 ) {
        $prev_month = 12;
        $year -= 1;
    }

    # determine the dates
    #~~~~~~~~~~~~~~~~~~~~
    my $filename_d  = $dates[0];
    my $filename_m  = $dates[2];
    my $file_d      = $dates[1];
    my $file_m      = sprintf ( "%04d%02d", $year, $prev_month );
    my $filename_il = $dates[3];

    $logger->info (">>> Dates filename: IC daily [$filename_d] - IC monthly [$filename_m] - IL [$filename_il]");
    $logger->info (">>> Dates file    : daily [$file_d] - monthly [$file_m]");

    my %dates = ( filename_d => $filename_d, filename_m => $filename_m , file_d => $file_d, file_m => $file_m, filename_il => $filename_il );

    return %dates;

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
