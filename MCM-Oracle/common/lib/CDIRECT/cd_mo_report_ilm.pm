package CDIRECT::cd_mo_report_ilm;

use CDIRECT::cd_cdirect;

our @ISA = qw(CDIRECT::cd_cdirect) ;

use warnings;
use strict;

#--------------------#
sub get_send         {
#--------------------#

    my ( $self ) = @_;

    my $logger   = $self->{logger} ;
    my $content  = $self->{content} ;

    if ( $content eq 'PF' && $self->check_closing_day () > 0 ) {

       $self->{send} = 'N' ;

       $logger->info("CDIRECT INFO : all branches closed, IL(portfolio) file not send !!");

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

    ##RAC1203 : For ILMARKETS the PF file needs to be generated with the BO date, otherwise we have issues when BR is closed and Asia branches are open (new-year, easter, ...)
    my %mx_dates     = %{$self->{mx_dates}}  ;
    my $bo_year      = substr( $mx_dates{ bo_date } , 2, 2 ) ;
    my $bo_month     = substr( $mx_dates{ bo_date } , 4, 2 ) ;
    my $bo_day       = substr( $mx_dates{ bo_date } , 6, 2 ) ;
    my $rundate_pf   = $bo_day . $bo_month . $bo_year ;

    my %dates        = $self->get_dates();

    ##Short entity exception for ABSOLUT bank, the short entity used for sending to ICRAP is CT iso AB (we use this also for IL)
   
    if ( $short_entity eq "AB" ) {
        $short_entity = "CT";
    }

    my $env          = get_env( $self->{pillar} );
    my %filenumbers  = ( BR => '01', CG => '02', FR => '03', LO => '04', NL => '05', HK => '06', SH => '08', SI => '15', TW => '13', CT => '00', FP => '29' );
    my $filenumber   = $filenumbers{ $short_entity };

    my %IL_files_daily   = ( PL     => 'D' . $env . '.WMX.V.MXPLOF.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber,
                             TR     => 'D' . $env . '.WMX.V.MXTRX1.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber,
                             UDF    => 'D' . $env . '.WMX.V.MXTRX2.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber,
                             PF     => 'D' . $env . '.WMX.V.MXPORT.R0001.D.ASC.S' . $rundate_pf,
                             CS     => 'D' . $env . '.WMX.V.MXCHFL.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber,
                             POS    => 'D' . $env . '.WMX.V.MXPOS1.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber,
                             DET    => 'D' . $env . '.WMX.V.MXCALP.R0001.D.ASC.S' . $dates{ filename_il } . '.F' . $filenumber  );

    my $filename = $IL_files_daily{ $content };

    $self->{localfile} = $filename ;

    ##From RAC1310 we will send empty files towards Ilmarkten

    if ( -f $self->{localdir} . '/' . $self->{localfile} && $short_entity ne "LO" ) {

          unlink $self->{localdir} . '/' . $self->{localfile} ;

    }

    if ( ! -f $self->{localdir} . '/' . $self->{localfile} ) {
          print "File not found, sending dummy file ... \n";
          $logger->info('Sending dummy file ... ') ;
          open (OUTPUTFILE, ">$self->{localdir}/$self->{localfile}") || $logger->logdie ('Could not open file :' . $self->{localdir} . '/' . $self->{localfile} . '.' );
          close (OUTPUTFILE) || $logger->logdie ("Can't close $!");
    }

    return $self->{localfile} ;

}


#-----------------#
sub get_remotedir {
#-----------------#

    my ( $self ) = @_;

    $self->{remotedir} = '/ontw/data/l60';

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

  if ( $self->{target} eq 'IL' ) {

     $self->{template_keyfile} = 'ILMARKETS_TEMPLATE.key' ;

  }

  return $self->{template_keyfile} ;

}

#-----------------------#
sub get_wmxkeyfile {
#-----------------------#

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

    my $path = $config->KBC_RUNDIR . '/ictoday_' . $short_entity . '.prn';

    ###Solution for sending FR/NL files
    if ( $short_entity eq "NL" || $short_entity eq "FR" ) {
       $path = $config->KBC_RUNDIR . '/ictoday_TEST' . '.prn' ;
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


#-----------------------#
sub check_closing_day   {
#-----------------------#

    my ( $self ) = @_;

    my $logger      = $self->{logger} ;
    my $sybase      = $self->{sybase} ;

    my $open_day = 0 ;
    my ($query, $query_result ) ;
    $query = "select count(*)
             from CAL_HOL_DBF T1
             where T1.M_CAL_LABEL
                in ('XACPTCNY',
                    'XACPTEURO',
                    'XACPTHONGK',
                    'XACPTLONDO',
                    'XACPTFP',
                    'XACPTSGD')
             and convert(char(11),M_DATE)  = convert(char(11),getdate() )
             ";

    unless ( $query_result = $sybase->query( query => $query ) ) {
            $logger->error ("Couldn\'t count occurences of closing days in CAL_HOL_DBF");
            return 0;
    }

    my @query1 = $query_result->next;
    $logger->info ("Count1 = $query1[0]");

    $query = "select count(*)
             from CAL_HOL_DBF T1
             where T1.M_CAL_LABEL
                in ('HONG KONG',
                    'CNY',
                    'SINGAPORE',
                    'LONDON',
                    'IBSFP',
                    'EURO')
             and convert(char(11),M_DATE)  = convert(char(11),getdate() )
             ";

    unless ( $query_result = $sybase->query( query => $query ) ) {
            $logger->error ("Couldn\'t count occurences of closing days in CAL_HOL_DBF");
            return 0;
    }

    my @query2 = $query_result->next;


    $logger->info ("Count2 = $query2[0]");

    if ( $query1[0] == 6 || $query2[0] == 6 ) {
        $open_day = 1 ;
    }


    return ( $open_day ) ;

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
