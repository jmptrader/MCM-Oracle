#!/usr/bin/env perl 

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase2;
use Mx::Util;
use Mx::Scheduler;
use Mx::Process;
use Mx::DBaudit;
use Mx::Report;
use Mx::Alert;
use Mx::Datamart::Common;
use Date::Calc ( 'Days_in_Month' );

use Getopt::Long;
use Switch ;
use File::Copy;
use File::Basename;
use File::Glob;
use File::Spec;

use CDIRECT::cd_fo_absolut;
use CDIRECT::cd_mo_report_icm;
use CDIRECT::cd_mo_report_ilm;
use CDIRECT::cd_mo_report_ibs;
use CDIRECT::cd_mo_report_vrm;
use CDIRECT::cd_mo_report_abm;
use CDIRECT::cd_mo_report_alm;
use CDIRECT::cd_bo_accounting;
use CDIRECT::cd_bo_accruals;
use CDIRECT::cd_bo_conf;
use CDIRECT::cd_bo_pay;
use CDIRECT::cd_tc_eai;
use CDIRECT::cd_tc_extract;
use CDIRECT::cd_xx_md;
use CDIRECT::cd_xx_uri;

#---------#
sub usage {
#---------#
    print <<EOT
Usage: cdirect.pl -project <project> -content <content> -target <target> -sched_js <jobstream>  [ -segment <segment of remote dir ] [ -no_output ]

 -project       <project>                      mandatory
 -content       <content>                      mandatory
 -target        <target>                       mandatory
 -sched_js      <jobstream>                    mandatory
 -segment       <segment>                      optional
 -no_output     No output displayed in TWS     optional
 -help          Display this text

EOT
;
    exit 1;
};

# 
# store away the commandline arguments for later reference
#
my $args = "@ARGV";


#
# get the script arguments
#
my ($glob_project, $glob_jobstream, $glob_content) ;
my ($glob_segment, $glob_target, $glob_keyfile, $glob_runtype, $glob_keyfile_path, $glob_no_output, $cdkeyfile ) ;
my ($glob_short_entity, $glob_entity, $glob_pillar ) ;

GetOptions(
    'help'              => \&usage,
    'project=s'         => \$glob_project,
    'sched_js=s'        => \$glob_jobstream,
    'content=s'         => \$glob_content,
    'segment=s'         => \$glob_segment,
    'runtype=s'         => \$glob_runtype,
    'no_output!'        => \$glob_no_output,
    'target=s'          => \$glob_target
);

unless ( $glob_project && $glob_jobstream && $glob_content && $glob_target ) {
    usage();
};


#
# read the configuration files
#

my $config = Mx::Config->new();
$config->set_project_variables( $glob_project );


#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->KBC_LOGDIR, keyword => $glob_jobstream );
$logger->info("cdirect.pl $args");
my $hostname = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;

#
# First check if C:D is enabled
#

if ( $config->CDIRECT_DISABLED eq 'N' ) {

   $logger->info("C:D is allowed on this environment, proceeding ...");

} else {

   $logger->info("C:D is not allowed on this environment, see environment config file (CDIRECT_DISABLED parameter) !");
   exit 0 ;

}

#
# Initialize alerting
#
my $alert = Mx::Alert->new( name => 'cdirect_failure', config => $config, logger => $logger );

#
# connect to the monitoring database
#
my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#
# setup the Sybase SA account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase2->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );


#
# open then Sybase connection
#
unless ( $sybase->open() ) {
    $logger->logdie ("Open sybase connection failed");
};





####----MAIN----------------------------------------------------------------------------------------------------------------------------------##

#
### Declare/initialize extra variables
#

my ( $id, $host, $starttime, $endtime, $success, $rc, $output, $pid ) ;
my ( $filesize, $filelength, $username, $cdirect ) ;

$glob_entity       = Mx::Scheduler->entity( $glob_jobstream );
$glob_short_entity = Mx::Scheduler->entity_short( $glob_jobstream );
$glob_runtype      = $glob_runtype || Mx::Scheduler->runtype( $glob_jobstream );
$glob_pillar       = Mx::Scheduler->pillar( $glob_jobstream );

my $reruns            = 0 ;
my $runtime           = 0 ;
my $exitcode          = 0 ;
my $killed            = 0 ;
my $cdpid             = 0 ;
my $scriptname        = basename( $0 );
my $path              = dirname( $0 );
my $user              = getpwuid( $< );
my $logfile           = $logger->filename;
my $cmdline           = "$0 $args" ;
my %dateshifter       = ( 'EOM' => '0', 'EOM_5' => '0', 'N' => '0', 'O' => '0', '1' => '-1', 'V' => '-2', 'X' => '-3' );
my $dateshift         = $dateshifter{ $glob_runtype } ;
my %mx_dates          = get_dates();


#
### Create the key file
#

if ( ! $glob_segment ) { $glob_segment  = '' ; } ;


switch ( $glob_project ) {

        case "fo_absolut" {

               $cdirect = CDIRECT::cd_fo_absolut->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "mo_report_icm" { 

               $cdirect = CDIRECT::cd_mo_report_icm->new( config       => $config,
                                                          logger       => $logger, 
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "mo_report_ilm" {

               $cdirect = CDIRECT::cd_mo_report_ilm->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "mo_report_abm" {

               $cdirect = CDIRECT::cd_mo_report_abm->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "mo_report_alm" {

               $cdirect = CDIRECT::cd_mo_report_alm->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }


        case "mo_report_ibs" {

               $cdirect = CDIRECT::cd_mo_report_ibs->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "mo_report_vrm" {

               $cdirect = CDIRECT::cd_mo_report_vrm->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }


        case "bo_accounting" {

               $cdirect = CDIRECT::cd_bo_accounting->new( config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                           ) ;
        }

        case "bo_conf" {

               $cdirect = CDIRECT::cd_bo_conf->new( config             => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                           ) ;
        }

        case "bo_pay" {

               $cdirect = CDIRECT::cd_bo_pay->new( config              => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                           ) ;
        }


        case "bo_accruals" {

               $cdirect = CDIRECT::cd_bo_accruals->new(   config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }


        case "xx_md" {

               $cdirect = CDIRECT::cd_xx_md->new(         config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "xx_uri" {

               $cdirect = CDIRECT::cd_xx_uri->new(        config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "tc_eai" {

               $cdirect = CDIRECT::cd_tc_eai->new(        config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates,
                                                          ) ;
        }

        case "tc_extract" {

               $cdirect = CDIRECT::cd_tc_extract->new(    config       => $config,
                                                          logger       => $logger,
                                                          sybase       => $sybase,
                                                          db_audit     => $db_audit,
                                                          runtype      => $glob_runtype,
                                                          pillar       => $glob_pillar,
                                                          short_entity => $glob_short_entity,
                                                          glob_entity  => $glob_entity,
                                                          content      => $glob_content,
                                                          target       => $glob_target,
                                                          segment      => $glob_segment,
                                                          mx_dates     => \%mx_dates, 
                                                          ) ;
        }


        else                 { print "No valid project defined !!\n" }

}  

$cdirect->CreateKeyFile() ;
my @fileprop = $cdirect->CalculateFileProps() ;

$filesize   = $fileprop[0] ;
$filelength = $fileprop[1] ;

$cdirect->Send_YN() ;



####----START CD----------------------------------------------------------------------------------------------------------------------------------##

$glob_keyfile_path = "$cdirect->{wmx_path}/$cdirect->{wmx_keyfile}" ;
$glob_keyfile      = "$cdirect->{wmx_keyfile}" ;
$cdkeyfile          = "/ontw/etc/ftkeys/wmx/$glob_keyfile";

print "CDIRECT INFO : Execute C:D keyfile : $glob_keyfile_path \n";
print "CDIRECT CMD  : /ontw/bin/D9R_FTCMD.pl -g wmx -k $glob_keyfile \n";

$logger->info("CDIRECT INFO : Execute C:D keyfile : $glob_keyfile \n");
$logger->info("CDIRECT CMD  : /ontw/bin/D9R_FTCMD.pl -g wmx -k $glob_keyfile.");

if ( $user !~ /^murexcd/ ) {

  my $process = Mx::Process->new( config => $config, logger => $logger );
  $pid        = $process->pid;
  $username   = $process->username;

} else {

  #You cannot use the Process object to get these variables, so let's use some unix cmd.
  $pid        = $$ ;
  $username   = $user ;

}


if ( $cdirect->EnableAudit() eq "Y" ) {

   $logger->info("Audit enabled, start update.");

   $id = $db_audit->record_transfer_start(
      hostname        => $hostname,
      project         => $glob_project,
      sched_jobstream => $glob_jobstream,
      entity          => $glob_entity,
      content         => $glob_content,
      target          => $glob_target,
      filesize        => $filesize,
      filelength      => $filelength,
      cmdline         => $cmdline,
      pid             => $pid, 
      cdpid           => $cdpid,
      username        => $username,
      logfile         => $logfile,
      cdkeyfile       => $cdkeyfile,
   );

} else {

   $logger->info("Audit disabled.");

}

$starttime = time() ;

while ( $reruns <= 1 ) {
    $exitcode = 0 ;
    ($success, $rc, $output, $cdpid) = Mx::Process->run( command => "/ontw/bin/D9R_FTCMD.pl -g wmx -k '$glob_keyfile'", config => $config, logger => $logger );
    #($success, $rc, $output, $cdpid) = Mx::Process->run( command => "sleep 70", config => $config, logger => $logger );
    $endtime   = time() ;
    if (! $success or $rc) {
       if ( $rc =~ /died/ ) { $killed = 1 ; } ;
       $exitcode = 1 ;
       $logger->warn("C:D failed");
       last if $reruns >= 1;
       $runtime = $endtime - $starttime ;
       if ( $runtime < 60 && $killed lt 1 ) {
          $logger->warn("runtime is $runtime seconds, going for a rerun of C:D in 10 seconds");
          sleep 10 ;
          $reruns++;
          next ;
       }
    }
    last ;
}

if ( $cdirect->EnableAudit() eq "Y" ) {

   $logger->info("Audit enabled, start update."); 

   $db_audit->record_transfer_end(
      id          => $id,
      exitcode    => $exitcode,
      cdpid       => $cdpid,
      reruns      => $reruns
   );

   if ( $killed gt 0 ) { $db_audit->mark_transfer_for_kill( id => $id ); } ;

} else {

  $logger->info("Audit disabled.");

}

$db_audit->close;

if (! $success or $rc) {
      $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $glob_jobstream, $glob_project, $glob_content, $glob_target, $glob_short_entity ], item => $glob_jobstream );
      unless ( $glob_no_output ) {
        print "CDIRECT INFO : CDIRECT FAILED !!!\n";
        print "----------------------------------------------------\n";
        print $output, "\n";
      }
      $logger->logdie ("CDIRECT INFO : CDIRECT FAILED !!!");
} else {
      unless ( $glob_no_output ) {
        print "CDIRECT INFO : OK !!!\n";
        print "----------------------------------------------------\n";
        print $output, "\n";
      }
      $logger->info("CDIRECT INFO : OK ");
      exit 0 ;
}


#--------------#
sub get_dates  {
#--------------#

  #
  ### Add an array for dates used by the DM reporting, this will eventually replace all the other dates also, it also contains an entry telling if we are on a closing day
  #

  print "glob_entity = $glob_short_entity \n" ;
  my $dm_date_entity = $glob_short_entity ;
  if ( $dm_date_entity eq 'XX' || $dm_date_entity eq 'NL' || $dm_date_entity eq 'FR' || $dm_date_entity eq 'AB' ) { $dm_date_entity = 'BR' }

  my $initial_db    = $sybase->database();
  my $plcc          = 'PLCC_' . $dm_date_entity ;
  my $sybase_clone  = $sybase->clone();
  my $calendar      = Mx::Murex->plcc_calendar( plcc => $plcc, sybase => $sybase_clone, library => $sql_library, logger => $logger );

  my $plcc_date     = Mx::Murex->date( type => 'MO', label => $plcc, calendar => $calendar, sybase => $sybase_clone, library => $sql_library, logger => $logger, config => $config );
  my $plcc_corr     = $plcc_date ;

  if ( $dateshift ne '0' ) {

     $plcc_corr = Mx::Murex->date_shift( date => $plcc_date, shift => $dateshift, calendar => $calendar, library => $sql_library, sybase => $sybase_clone, logger => $logger );

  }

  my $bo_date       = Mx::Murex->date(type => 'BO', label => 'PC_BRUSSELS', shift => '0', sybase => $sybase_clone, library => $sql_library, config => $config, logger => $logger) ;
  my $bu_date       = Mx::Murex->businessdate( config => $config, logger => $logger );
  my $sys_date      = Mx::Util->epoch_to_iso();

  my ($sec,$min,$hour,$day, $month, $year) = ( localtime( time() ) )[0..5];
  my $cal_date       = sprintf ("%04s%02s%02s%02s%02s%02s", $year + 1900, ++$month, $day,$hour,$min,$sec);
  my $cal_date_short = sprintf ("%04d%02d%02d", $year + 1900, ++$month, $day);

  my $prev_eom_date   = Mx::Murex->previous_eom_date( config => $config, sybase => $sybase_clone, library => $sql_library, plcc => $plcc, logger => $logger );
  my $no_days         = Days_in_Month( substr($prev_eom_date,0,4), substr($prev_eom_date,4,2) );
  my $last_cal_day    = substr($prev_eom_date,0,6) . $no_days;

  my $is_holiday     = 0 ;

  if (Mx::Murex->is_holiday( date => $bu_date, calendar => $calendar, sybase => $sybase_clone, library => $sql_library, config => $config, logger => $logger ) ) {

      $is_holiday = 1 ;

  }


  $sybase->use( $config->DB_REP );

  $sybase->use( $initial_db );

  my %mx_dates  = ( plcc_date => $plcc_date, plcc_corr => $plcc_corr, bo_date => $bo_date, bu_date => $bu_date, sys_date => $sys_date, cal_date => $cal_date, cal_date_short => $cal_date_short, last_cal_day => $last_cal_day, is_holiday => $is_holiday );

  $logger->info("plcc_date = $mx_dates{plcc_date}, plcc_corr = $mx_dates{plcc_corr}, bo_date = $mx_dates{bo_date}, bu_date = $mx_dates{bu_date}, sys_date = $mx_dates{sys_date}, cal_date = $mx_dates{cal_date}, is_holiday = $mx_dates{is_holiday}") ;

  print " plcc_date = $mx_dates{plcc_date}, dateshift = $dateshift, plcc_corr = $mx_dates{plcc_corr}, bo_date = $mx_dates{bo_date}, bu_date = $mx_dates{bu_date}, sys_date = $mx_dates{sys_date}, cal_date = $mx_dates{cal_date}, last_cal_day = $last_cal_day, is_holiday = $mx_dates{is_holiday} \n " ;

  return %mx_dates ;

}
