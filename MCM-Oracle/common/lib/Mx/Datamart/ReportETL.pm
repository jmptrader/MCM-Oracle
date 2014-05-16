package Mx::Datamart::ReportETL;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Exporter;
use Mx::Datamart::Report;
use Mx::Datamart::Tables;
use Mx::Murex;
use Mx::Sybase;
our @SIA = qw(Exporter);
our @EXPORT = qw( create_report load report script update_statistics $CDIRECT $LABEL $IN_LABEL $OUT_LABEL $READ $TEMP $TRANSFER $WRITE); 

our $CDIRECT   = 'cdirect';
our $LABEL     = 'label';
our $IN_LABEL  = 'in_label';
our $OUT_LABEL = 'out_label';
our $READ      = 'read';
our $SCRIPT    = 'DM_REPORT_ETL';
our $TEMP      = 'temp';
our $TRANSFER  = 'transfer'; 
our $WRITE     = 'write';

my  $self = {};

#-------#
sub new {
#-------#
  my ( $class, %args ) = @_;

  unless ( $self->{script} = $args{script} ) {
    croak 'script argument missing in ReportETL->new';
  }
  my $script = $self->{script};
  my $config = $self->{config} =  $self->{script}->{config};  
  my $logger = $self->{logger} = $self->{script}->{logger};  

  unless ( $self->{report_etl_config} = $args{report_etl_config} ) {
    $script->fail_and_die( 'report_etl_config argument missing in ReportETL->new' );
  }
  my $report_etl_config = $self->{report_etl_config};
  
  unless ( $self->{scheduler} = $args{scheduler} ) {
    $script->fail_and_die( 'scheduler argument missing in ReportETL->new' );
  } 
  my $scheduler = $self->{scheduler};

  unless ( $self->{sql_library} = $args{sql_library} ) {
    $script->fail_and_die( 'sql_library argument missing in ReportETL->new' );
  } 
  
  unless ( $self->{sybase} = $args{sybase} ) {
    $script->fail_and_die( 'sybase argument missing in ReportETL->new' );
  }
  my $sybase = $self->{sybase};
  
  my $table_name = $report_etl_config->{table_name};
  my $tables = Mx::Datamart::Tables->new( logger => $logger, config => $config, sched_js => $scheduler->{jobstream}, sybase => $sybase, table => $table_name );
  $self->{tables} = $tables;
  
  $table_name = $tables->get_table_name( table => $table_name );
  $self->{table_name} = $table_name;

  _initialize_report_etl_config();  
  
  bless $self, $class;
  return $self;
}

#---------------------------------# 
sub _initialize_report_etl_config {
#---------------------------------# 
  my $config      = $self->{config};
  my $logger      = $self->{logger};
  my $scheduler   = $self->{scheduler}; 
  my $script      = $self->{script};   
  my $sql_library = $self->{sql_library};

  #
  # setup the Sybase connection
  #
  my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
  my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );
  unless ( $sybase->open() ) {
    $script->fail_and_die( 'Open sybase connection failed' );
  };

  # set report_date
  my $report_date;
  my $plcc = 'PLCC_' . $scheduler->entity;
  $report_date = Mx::Murex->date( 
    type => 'MO', label => $plcc, 
    sybase => $sybase, library => $sql_library, 
    config => $config, logger => $logger );
  if ( $report_date ) {
  # noaction
  } else {
    $report_date = Mx::Murex->businessdate( config=> $config, logger => $logger );
  }
  $report_date = substr( $report_date, 2, 6 );

  # report_etl_config
  my $short_entity = $scheduler->entity_short;
  $self->{report_etl_config}->{file_name}  =~ s/__ENTITY__/$short_entity/g;
  $self->{report_etl_config}->{file_name}  =~ s/__DATE__/$report_date/g;

  #
  # close sybase connection
  #
  $sybase->close();

}

#-----------------#
sub create_report {
#-----------------#
  my ( $self, %args ) = @_;
  my $report_etl_config = $self->{report_etl_config};
  my $script            = $self->{script};
  
  my $label;
  unless ( $label = $args{label} ) {
    $script->fail_and_die( 'label argument missing in ReportETL->create_report' );  
  }
  unless ( $label = $report_etl_config->{$label} ) {
    $script->fail_and_die( 'label not found in config file for ' . $SCRIPT );
  }

  my $location;
  unless ( $location = $args{location} ) {
    $script->fail_and_die( 'location argument missing in ReportETL->create_report' );  
  }  

  my $mode;
  unless ( $mode = $args{mode} ) {
    $script->fail_and_die( 'mode argument missing in ReportETL->create_report' );  
  }    

  my $report = Mx::Datamart::Report->new ( 
    name => $report_etl_config->{file_name},
	  location => $location, 
	  label => $label,
	  script => $script );
  $report->open( mode => $mode );

  my $old_size = -1;
  my $new_size = -s $report->path; 
  while ( $old_size ne $new_size ) {
    sleep 5;
    $old_size = $new_size;
    $new_size = -s $report->path;
  }  

  $self->{report} = $report;
  return $report;
}	

#--------#
sub load {
#--------#
  my $config            = $self->{config};
  my $report_etl_config = $self->{report_etl_config};
  my $report            = $self->{report};
  my $script            = $self->{script};
  my $sybase            = $self->{sybase};
  
  unless ( 
    $sybase->bcp_in( 
      file => $report->path, 
      table => 'MUREXDB.' . $self->{table_name}, 
      format => $config->KBC_CONFDIR . '/' . $report_etl_config->{bcp_format}, 
      delimiter => "" )) {
    $script->fail_and_die( "bcp_in failed" );
  }
}

#----------# 
sub report {
#----------#
  my ( %args ) = @_;
  ( $args{report} ) ? $self->{report} = $args{report} : return $self->{report};
}

#----------# 
sub script {
#----------#
  return $self->{script};
}

#---------------------#
sub update_statistics {
#---------------------#
  my $config            = $self->{config};
  my $logger            = $self->{logger};
  my $report_etl_config = $self->{report_etl_config};
  my $scheduler         = $self->{scheduler};
  my $sybase            = $self->{sybase};
  my $tables            = $self->{tables};

  $tables->update_statistics( table => $report_etl_config->{table_name} );
}	

###
1
