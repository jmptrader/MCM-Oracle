package Mx::Datamart::Common;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Mx::Scheduler;
use Mx::Util;

my ( $logger, $config, $sybase, $sql_library );

#------------#
sub _get_key {
#------------#
  my ( @args ) = @_;	
  my $key = "";
  foreach( @args ) {
    if (defined $_) {
  	  $key = $key . Mx::Util->trim($_);
    }
  }
  return $key;  	
}

#---------------#
sub convert_ccy {
#---------------#
  my ( $class, %args ) = @_;
  _initialize( %args );

  # exchange_rates 
  my $exchange_rates;
  unless ( $exchange_rates = $args{exchange_rates} ) {
    $logger->logdie("convert_ccy -  exchange_rates argument missing");
  }

  # instrument
  my $instrument;
  unless ( $instrument = $args{instrument} ) {
    $logger->logdie("convert_ccy -  instrument argument missing");
  }

  # values 
  my $value;
  if ( defined $args{value} ) {
  	$value = $args{value};
  } else {
    $logger->logdie("convert_ccy -  value argument missing");  	
  }  	

  unless ( $exchange_rates->{$instrument} ) {
    return undef;
  }

  my $return;
  if ( $exchange_rates->{$instrument} ) {
    if ( $value =~ m/e/ ) {
      $return = undef;
    } else {
      my $format = '%.' . $exchange_rates->{$instrument}->{precision} . 'f';
      $return = sprintf ( $format , $value * $exchange_rates->{$instrument}->{exchange_rate} );
      if ( ($return * 1) =~ m/e/ ) {
        _set_sql_library( %args );
        # query
        my $sql_query = 'select round(' . $value . '*' . $exchange_rates->{$instrument}->{exchange_rate} . ', ' . $exchange_rates->{$instrument}->{precision} . ')';
        my $result;
        unless ( $result = $sybase->query( query => $sql_query, logger => $logger, quiet => 1 )) {
           $logger->logdie("exception - cannot execute query - $sql_query");
        }
        my @sql_value = $result->next;
        if ( index($sql_value[0], '.') > -1 ) {
          $return = substr( $sql_value[0], 0, index($sql_value[0], '.') + $exchange_rates->{$instrument}->{precision} + 1 );
        } else {
          $return = $sql_value[0];
        }
      }
    }    
  } else {
    $return = undef;
  } 
  return $return;
}

#-----------------#
sub get_dyn_audit {
#-----------------#
  my ( $class, %args ) = @_;
  _initialize( %args );
  _set_sql_library( %args );

  # 
  my ( $sched_js, $entity, $runtype, $run_entity );
  unless ( $sched_js = $args{sched_js} ) {
    $logger->logdie("get_dyn_audit - sched_js argument(s) missing");
  }
  unless ( $entity = $args{entity} ) {
    $entity     = Mx::Scheduler->entity_short( $sched_js );
  }
  unless (  $runtype = $args{runtype} ) {
    $runtype    = Mx::Scheduler->runtype( $sched_js );
  }
  $run_entity = $runtype . $entity;

  # output_table
  my $output_table;
  unless ( $output_table = $args{output_table} ) {
    $logger->logdie("get_dyn_audit_ref_data_and_rep_date2 - output_table argument missing");
  }
  $output_table =~ s/__ENTITY__/$entity/g;
  $output_table =~ s/_REP$/.REP/g;
  $logger->info("DYN_AUDIT_REP - M_OUTPUTTBL [ $output_table ] | M_TAG_DATA [ $run_entity ]");

  # query
  my $result;
  my $sql_query = $sql_library->query( 'select_dyn_audit' );
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ,  $run_entity ], quiet => 1 )) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
  unless ( $result->size() > 0 ) {
  # try default output_table
    my $output_table = 'B' . $entity . 'D_CFG_DATES.REP';

    $logger->info("DYN_AUDIT_REP - M_OUTPUTTBL [ $output_table ] | M_TAG_DATA [ $run_entity ]");

    unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ,  $run_entity ], quiet => 1 )) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
  }
  my %hash;
  if ( $result->size() > 0 ) {
    %hash = $result->next_hash();
    $hash{M_REP_DATE2} =  Mx::Util->convert_date( $hash{M_REP_DATE2} );
  }
  return  %hash;
}

#----------------------------------------#
sub get_dyn_audit_ref_data_and_rep_date2 {
#----------------------------------------#
  my ( $class, %args ) = @_;
  _initialize( %args );
  _set_sql_library( %args );

  #
  my ( $sched_js, $entity, $runtype, $run_entity );
  unless ( $sched_js = $args{sched_js} ) {
    $logger->logdie("get_dyn_audit - sched_js argument(s) missing");
  }
  unless ( $entity = $args{entity} ) {
    $entity     = Mx::Scheduler->entity_short( $sched_js );
  } 
  unless (  $runtype = $args{runtype} ) {
    $runtype    = Mx::Scheduler->runtype( $sched_js );
  }
  $run_entity = $runtype . $entity;

  # output_table
  my $output_table = $args{output_table} || 'B__ENTITY__D_CFG_DATES.REP';
  $output_table =~ s/__ENTITY__/$entity/g;
  $output_table =~ s/_REP$/.REP/g;
  $logger->info("DYN_AUDIT_REP - M_OUTPUTTBL [ $output_table ] | M_TAG_DATA [ $run_entity ]");

  # query
  my $result;
  my $sql_query = $sql_library->query( 'select_dyn_audit_ref_data_and_rep_date2' );
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ,  $run_entity ], quiet => 1 )) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }
  unless ( $result->size() > 0 ) {
  # try default output_table 
    my $output_table = 'B' . $entity . 'D_CFG_DATES.REP';
    $logger->info("DYN_AUDIT_REP - M_OUTPUTTBL [ $output_table ] | M_TAG_DATA [ $run_entity ]");
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ,  $run_entity ], quiet => 1 )) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
  }

  unless ( $result->size() > 0 ) {
  # try default output_table, run_entity 
    my $output_table = 'BBRD_CFG_DATES.REP';
    my $run_entity   = 'OBR';
    $logger->info("DYN_AUDIT_REP - M_OUTPUTTBL [ $output_table ] | M_TAG_DATA [ $run_entity ]");
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ,  $run_entity ], quiet => 1 )) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
  }

  my ( $ref_data, $rep_date2 ) = $result->next;
  if ( defined( $ref_data ) && defined( $rep_date2 ) ) {
    $rep_date2 =  Mx::Util->convert_date( $rep_date2 );
    $logger->info( "DYN_AUDIT_REP - M_REF_DATA [ $ref_data ] | M_REP_DATE2 [ $rep_date2 ]" );
  } else {
     $logger->info( "DYN_AUDIT_REP - M_REF_DATA or M_REP_DATE2 undefined" ); 
  }
  return $ref_data, $rep_date2;
}

#------------------------------------#
sub get_last_o1vx_dyn_audit_rep_data {
#------------------------------------#
  my ( $class, %args ) = @_;
  _initialize( %args );
  _set_sql_library( %args );

  #
  my $sched_js;
  unless ( $sched_js = $args{sched_js} ) {
    $logger->logdie("get_last_o1vx_dyn_audit_rep_data - sched_js argument(s) missing");
  }
  my $entity_short = Mx::Scheduler->entity_short( $sched_js );

  # output_table
  my $output_table = $args{output_table} || 'B__ENTITY__D_CFG_DATES.REP';
  $output_table =~ s/__ENTITY__/$entity_short/g;
  $output_table =~ s/_REP$/.REP/g;

  # query
  my $result;
  my $sql_query = $sql_library->query( 'select_last_o1vx_dyn_audit_rep_data' );
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ], quiet => 1 )) {
    $logger->logdie("get_last_o1vx_dyn_audit_rep_data - cannot execute query - $sql_query");
  }
  unless ( $result->size() > 0 ) {
  # try default output_table
    $output_table = 'B' . $entity_short . 'D_CFG_DATES.REP';
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger,  values =>  [ $output_table ], quiet => 1 )) {
      $logger->logdie("get_last_o1vx_dyn_audit_rep_data - cannot execute query - $sql_query");
    }
  }
  my %hash = ();
  while (my %row = $result->next_hash) {
    my %hash_row = ();
    $row{M_REP_DATE2} =  Mx::Util->convert_date( $row{M_REP_DATE2} );
    %hash_row = (  
      $row{RUN} => { 
        M_REF_DATA  => $row{M_REF_DATA},
        M_REP_DATE2 => $row{M_REP_DATE2}
      }
    );
    @hash {keys %hash_row} = values %hash_row;
  }
  return %hash;
}

#----------------------#
sub get_exchange_rates {
#----------------------#
  my ( $class, %args ) = @_;
  _initialize( %args );
  _set_sql_library( %args );

  # report_date 
  my $report_date;
  unless ( $report_date = $args{report_date} ) {
    $logger->logdie("get_exchange_rates -  report_date argument missing");
  }

  # exchange_type
  my $exchange_type;
  unless ( $exchange_type = $args{exchange_type} ) {
    $exchange_type = 'REVAL FXMM';    
  }

  # queries
  my ( $sql_query, $result );
  my $hash = ();
  my @sql_array = ('select_exchange_rates_1', 'select_exchange_rates_2' );
  foreach my $sql ( @sql_array ) {
    $sql_query = $sql_library->query( $sql );
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger,
      values => [ $exchange_type, $report_date, $report_date ], quiet => 1 )) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
    while ( my ( @row ) = $result->next() ) {
      my ( $instrument, $exchange_rate, $precision ) = ( @row );
      if ( exists $hash->{$instrument} ) {
        ### no action
      } else {
        $hash->{$instrument}->{exchange_rate} = $exchange_rate;
        $hash->{$instrument}->{precision} = $precision; 
      }
    }
  }
  @sql_array = ('select_exchange_rates_3', 'select_exchange_rates_4' );
  foreach my $sql ( @sql_array ) {
    $sql_query = $sql_library->query( $sql );
    unless ( $result = $sybase->query( query => $sql_query, logger => $logger, quiet => 1 )) {
      $logger->logdie("exception - cannot execute query - $sql_query");
    }
    while ( my ( @row ) = $result->next() ) {
      my ( $instrument, $exchange_rate, $precision ) = ( @row );
      if ( exists $hash->{$instrument} ) {
        ### no action
      } else {
        $hash->{$instrument}->{exchange_rate} = $exchange_rate;
        $hash->{$instrument}->{precision} = $precision;
      }
    }
  }
  # extended queries
  if ( $args{extended} ) {
    if ( $args{extended} == 1 ) { 
      @sql_array = ('select_last_valid_exchange_rates_1', 'select_last_valid_exchange_rates_2');
      foreach my $sql ( @sql_array ) {
        $sql_query = $sql_library->query( $sql );
        unless ( $result = $sybase->query( query => $sql_query, logger => $logger,
          values => [ $exchange_type ], , quiet => 1 )) {
          $logger->logdie("exception - cannot execute query - $sql_query");
        }
        while ( my ( @row ) = $result->next() ) {
          my ( $instrument, $exchange_rate, $precision ) = ( @row );
          if ( exists $hash->{$instrument} ) {
            ### no action
          } else {
            $hash->{$instrument}->{exchange_rate} = $exchange_rate;
            $hash->{$instrument}->{precision} = $precision;
          }
        }
      }
    }
  }
  return $hash;
}

#---------------#
sub get_mapping {
#---------------#
  my ( $class, %args ) = @_;
  _initialize( %args );
  _set_sql_library( %args );

  # query
  my $result;
  my $sql_query = $sql_library->query( 'select_mapping' );
  unless ( $result = $sybase->query( query => $sql_query, logger => $logger, quiet => 1 ) ) {
    $logger->logdie("exception - cannot execute query - $sql_query");
  }     
  my $hash = ();
  while ( my ( @row ) = $result->next() ) {
    my $key = _get_key(@row[2..10]);
    my $destination = ();
    my $count = 1;
    foreach my $value ( @row[11..19] ) {
      $destination->{$count} = $value;
      $count++;
    }
    my $type = Mx::Util->trim($row[0]);
    $hash->{$type}->{$key}=$destination;
  }
  return $hash;  

}

#---------------#
sub _initialize {
#---------------#

  my ( %args ) = @_;

  # logger
  $logger = $args{logger} or croak "initialize- logger argument missing";

  # config
  unless ( $config = $args{config} ) {
    $logger->logdie("initialize -  config argument missing");
  }

  # sybase
  unless ( $sybase = $args{sybase} ) {
    $logger->logdie("initialize -  sybase argument missing");
  }
  unless ( ref($sybase) eq 'Mx::Sybase2') {
    $logger->logdie("initialize - sybase argument is not of type Mx::Sybase2");
  }

}

#--------------------#
sub _set_sql_library {
#--------------------#
  my ( %args ) = @_;
  if ( $args{sql_library} ) {
    $sql_library = $args{sql_library};
  } else {
    $sql_library = Mx::SQLLibrary->new( file => $config->SQLDIR . '/library.sql', logger => $logger );
  }
}

###
1
