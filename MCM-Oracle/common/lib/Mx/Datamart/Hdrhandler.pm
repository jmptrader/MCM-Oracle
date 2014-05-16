package Mx::Datamart::Hdrhandler;

use Carp;
use Mx::Util;
use strict;
use Switch;
use warnings;

use Date::Calc ( 'Days_in_Month' );
use XML::SAX::Base;
use vars qw( @ISA );
@ISA = qw( XML::SAX::Base );

my $cosys = '';
my $count = 0;
my ( $cur_yyyymmdd, $cur_yyyy_mm_dd, $cur_yyyy_mm_dd_hh_mm_ss );
my ( $ddmmyy, $yymmdd, $yyyy_mm_dd, $yyyy_mm_dd_hh_mm_ss );
my ( $eom_ddmmyy, $eom_yyyy_mm_dd, $eom_yyyy_mm_dd_hh_mm_ss );
my $dcm_lyot_cd = '';
my $dcm_lyot_nm = '';
my $dcm_lyot_vsn_no = undef;
my $file_name = '';
my $path = '';
my $pillar = '';
my $run_type;
my $scheduler = undef;
my $entity = undef;
my $xml = '';

#--------------#
sub characters {
#--------------#	
  my ($self, $characters) = @_;
  switch ($path) {
    case '/TECHN_HDR/DCM_LYOT/DCM_LYOT_CD' {
     $xml = $xml . $dcm_lyot_cd; 
    }
    case '/TECHN_HDR/DCM_LYOT/DCM_LYOT_NM' {
     $xml = $xml . $dcm_lyot_nm;
    }
    case '/TECHN_HDR/DCM_LYOT/DCM_LYOT_VSN_NO' {
     $xml = $xml . $dcm_lyot_vsn_no;
    }
    case ['/TECHN_HDR/DY_MNH_IC', '/TechnicalHeader/DayMonthIndicator'] {
     $xml = $xml . $run_type;
    }
    case ['/TECHN_HDR/TNC_HDR_L_ID', '/TechnicalHeader/Label'] {
      $xml = $xml . '$~&gt;TECHN-HEADER&lt;~$';
    }  	
    case ['/TECHN_HDR/EVR_CD', '/TechnicalHeader/Environment'] {
      $xml = $xml . $pillar;
    }
    case ['/TECHN_HDR/EXPT_PUB_MSG_QT', '/TECHN_HDR/ATL_PUB_MSG_QT', '/TechnicalHeader/ExpectedPublishedMessages', '/TechnicalHeader/ActualPublishedMessages']  {
      $xml = $xml . $count;
    }
    case ['/TECHN_HDR/FILE_NM', '/TechnicalHeader/FileName'] {
      $file_name = $characters->{Data};
      $file_name =~ s/__COSYS__/$cosys/g;
      $file_name =~ s/__DCM_LYOT_CD__/$dcm_lyot_cd/g;
      if ( defined $dcm_lyot_vsn_no ) { 
        my $vsn_no =  substr( $dcm_lyot_vsn_no,0,2 ).substr( $dcm_lyot_vsn_no,3,2 );
        $file_name =~ s/__DCM_LYOT_VSN_NO__/$vsn_no/g;
      }
      $file_name =~ s/__PILLAR__/$pillar/g;      
      $file_name =~ s/__RUN_TYPE__/$run_type/g;
      if ( $scheduler->runtype eq 'X' ) {
        $file_name =~ s/__DDMMYY__/$eom_ddmmyy/g;
      } else {
        $file_name =~ s/__DDMMYY__/$ddmmyy/g;
      }    		
      $xml = $xml . $file_name;
    } 
    case ['/TECHN_HDR/PUB_TS', '/TechnicalHeader/ExecutionTimestampPublisher'] {
      $xml = $xml . $cur_yyyy_mm_dd_hh_mm_ss;
    }
    case ['/TECHN_HDR/SSB_TS', '/TECHN_HDR/REF_TS', '/TechnicalHeader/ExecutionTimestampSubscriber', '/TechnicalHeader/ReferenceTimestamp'] {
      if ( $scheduler->runtype eq 'X' ) {
        $xml = $xml . $eom_yyyy_mm_dd_hh_mm_ss;
      } else {
        $xml = $xml . $yyyy_mm_dd_hh_mm_ss;
      }
    }  	 	
    case ['/TECHN_HDR/PUB_EXC_DT', '/TechnicalHeader/ExecutionDatePublisher'] {
      if ( $scheduler->runtype eq 'X' ) {
        $xml = $xml . $eom_yyyy_mm_dd;
      } else {
        $xml = $xml . $yyyy_mm_dd;
      }
    }  	 	  	
    else { $xml = $xml . $characters->{Data}; }  	
  }  	
}	

#---------------#
sub end_element {
#---------------#	
  my ($self, $element) = @_;
  switch ($path) {
    case ['/TECHN_HDR', '/TechnicalHeader'] {
      $xml = $xml . '</' . $element->{Name} . '>';    
    }  
    else {
      $xml = $xml . '</' . $element->{Name} . '>' . "\n";        	
    }
  }
  
  $path = substr( $path, 0, length($path) - length($element->{Name}) - 1);
}

#-----------------#
sub get_file_name {
#-----------------#
  my ($self) = @_;  	
  return $file_name;
}

#---------------------#
sub get_file_name_ems {
#---------------------#
  my ($self, $file_name_ems) = @_;
  $file_name_ems =~ s/__PILLAR__/$pillar/g;
  $file_name_ems =~ s/__YYMMDD__/$yymmdd/g;
  $file_name_ems =~ s/__ENTITY__/$entity/g;
  return $file_name_ems;
}	

#-----------#
sub get_xml {
#-----------#	
  my ($self, $element) = @_;
  return $xml;
}

#-------------#
sub set_cosys {
#-------------#
  my ($self, $value ) = @_;
  $cosys = $value;
}

#-------------#
sub set_count {
#-------------#	
  my ($self, $value ) = @_;
  $count = $value;
}

#-------------------# 
sub set_dcm_lyot_cd {
#-------------------#
  my ($self, $value ) = @_;
  $dcm_lyot_cd = $value;
}

#-------------------# 
sub set_dcm_lyot_nm {
#-------------------#
  my ($self, $value ) = @_;
  $dcm_lyot_nm = $value;
  $dcm_lyot_nm =~ s/\&/\&amp\;/g;
}

#-----------------------#
sub set_dcm_lyot_vsn_no {
#-----------------------#
  my ($self, $value ) = @_;
  $dcm_lyot_vsn_no = $value;
}

#--------------#
sub set_pillar {
#--------------#	
  my ($self, $value) = @_;
  $pillar = $value;
}

#-------------------#
sub set_report_date {
#-------------------#
  my ($self, $value) = @_;
  my ( $yy, $yyyy, $mm, $dd );
  if ( $value =~ m/^[0-9]{4}-[0-9]{2}-[0-9]{2}.*/ ) {
    $yy   = substr( $value, 2, 2 );
    $yyyy = substr( $value, 0, 4 );
    $mm   = substr( $value, 5, 2 );
    $dd   = substr( $value, 8, 2 );
  } else {
    $yy   = substr( $value, 2, 2 );
    $yyyy = substr( $value, 0, 4 );
    $mm   = substr( $value, 4, 2 );
    $dd   = substr( $value, 6, 2 );
  }
  $ddmmyy                  = $dd . $mm . $yy;
  $yyyy_mm_dd              = $yyyy  . '-' . $mm . '-' . $dd;
  $yymmdd                  = $yy . $mm . $dd;
  $yyyy_mm_dd_hh_mm_ss     = $yyyy_mm_dd . '-18.00.00';
  my $days_in_month        = Days_in_Month( $yyyy, $mm );
  $eom_ddmmyy              = $days_in_month . $mm . $yy;
  $eom_yyyy_mm_dd          = $yyyy  . '-' . $mm . '-' . $days_in_month; 
  $eom_yyyy_mm_dd_hh_mm_ss = $eom_yyyy_mm_dd . '-18.00.00';
}

#----------------#
sub set_run_type {
#----------------#
  my ($self, $value) = @_;
  $run_type = $value;
}

#-----------------#
sub set_scheduler {
#-----------------#
  my ($self, $value) = @_;
  $scheduler = $value;
}
#-----------------#
sub set_entity {
#-----------------#
  my ($self, $value) = @_;
  $entity = $value;
}

#-----------#
sub set_xml {
#-----------#	
  my ($self) = @_;
  $xml = '';
}

#-----------------#
sub start_element {
#-----------------#
  my ($self, $element) = @_;
  $path = $path . '/' . $element->{Name};
  $xml = $xml . '<' . $element->{Name} . '>';
  switch ($path) {
    case ['/TECHN_HDR', '/TECHN_HDR/DCM_LYOT', '/TechnicalHeader', '/TechnicalHeader/DocumentLayout'] {
      $xml = $xml . "\n";
    }
  }  
}

#-------#
sub new {
#-------#
  my ( $class, %args ) = @_;
  my $self = {};

  $cur_yyyymmdd = Mx::Util->epoch_to_iso();
  $cur_yyyy_mm_dd = substr( $cur_yyyymmdd, 0, 4 ) . '-' . substr( $cur_yyyymmdd, 4, 2 ) . '-' . substr( $cur_yyyymmdd, 6, 2 );
  $cur_yyyy_mm_dd_hh_mm_ss = $cur_yyyy_mm_dd . '-18.00.00';
  
  bless $self, $class;
  return $self;
}

###
1 
