package Mx::Mason::Config;

use strict;
use warnings;

my $config;
my $logger;


#-------------------#
sub setup_callbacks {
#-------------------#
    my ( $class, %args ) = @_;


    $config = $args{config};
    $logger = $args{logger};

    $HTML::Mason::Commands::callbacks{ histfeedertable } = \&Mx::Mason::Config::histfeedertable;
    $HTML::Mason::Commands::callbacks{ histdmreport }    = \&Mx::Mason::Config::histdmreport;
    $HTML::Mason::Commands::callbacks{ histwebcommand  } = \&Mx::Mason::Config::histwebcommand;
    $HTML::Mason::Commands::callbacks{ histscript }      = \&Mx::Mason::Config::histscript;
    $HTML::Mason::Commands::callbacks{ histstatement }   = \&Mx::Mason::Config::histstatement;
    $HTML::Mason::Commands::callbacks{ histblocker }     = \&Mx::Mason::Config::histblocker;
    $HTML::Mason::Commands::callbacks{ histcore }        = \&Mx::Mason::Config::histcore;
    $HTML::Mason::Commands::callbacks{ histtransfer }    = \&Mx::Mason::Config::histtransfer;
    $HTML::Mason::Commands::callbacks{ histreport }      = \&Mx::Mason::Config::histreport;
    $HTML::Mason::Commands::callbacks{ histmessage }     = \&Mx::Mason::Config::histmessage;
    $HTML::Mason::Commands::callbacks{ md_upload }       = \&Mx::Mason::Config::md_upload;
    $HTML::Mason::Commands::callbacks{ histruntime }     = \&Mx::Mason::Config::histruntime;
    $HTML::Mason::Commands::callbacks{ histimstatus }    = \&Mx::Mason::Config::histimstatus;
}

#-------------------#
sub histfeedertable {
#-------------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Datamart Feeder Table';
    $HTML::Mason::Commands::search_button   = ( $args{session_id} ) ? 0 : 1;
    $HTML::Mason::Commands::go_back_button  = ( $args{session_id} ) ? 1 : 0;
    $HTML::Mason::Commands::refresh_button  = 0;
    $HTML::Mason::Commands::table_width     = '70%';
    $HTML::Mason::Commands::table_name      = 'feedertables';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_feedertables;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_feedertable;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',           label => 'ID',        desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histfeedertable_details.html', args => 'feeder_id:__id__', stype => 'free', slength => 6 },
      { name => 'session_id',   label => 'SESSION',   desc => 'Session ID',        visible => 0, numeric => 1, index => 2, stype => 'free', slength => 6 },
      { name => 'name',         label => 'NAME',      desc => 'Name',              visible => 1, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'batch_name',   label => 'BATCH',     desc => 'Batch Name',        visible => 1, numeric => 0, index => 4,  type => 'string', stype => 'list' },
      { name => 'feeder_name',  label => 'FEEDER',    desc => 'Feeder Name',       visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'list' },
      { name => 'entity',       label => 'ENTITY',    desc => 'Entity',            visible => 1, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'runtype',      label => 'RUNTYPE',   desc => 'Run Type',          visible => 1, numeric => 0, index => 7,  type => 'string', stype => 'list' },
      { name => 'tabletype',    label => 'TABLETYPE', desc => 'Table Type',        visible => 1, numeric => 0, index => 12, type => 'string', stype => 'list' },
      { name => 'timestamp',    label => 'TIMESTAMP', desc => 'Timestamp',         visible => 1, numeric => 1, index => 8,  type => 'timestamp' },
      { name => 'job_id',       label => 'JOB ID',    desc => 'Job ID',            visible => 1, numeric => 1, index => 9,  type => 'string', stype => 'free', slength => 6 },
      { name => 'ref_data',     label => 'REF DATA',  desc => 'Ref Data',          visible => 1, numeric => 0, index => 10, type => 'string', stype => 'free', slength => 6 },
      { name => 'nr_records',   label => '# RECORDS', desc => 'Number of Records', visible => 1, numeric => 1, index => 11, type => 'count' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#----------------#
sub histdmreport {
#----------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Datamart Report';
    $HTML::Mason::Commands::search_button   = ( $args{script_id} ) ? 0 : 1;
    $HTML::Mason::Commands::go_back_button  = ( $args{script_id} ) ? 1 : 0;
    $HTML::Mason::Commands::refresh_button  = 0;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'dm_reports';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_dm_reports;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_dm_report;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',            label => 'ID',            desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histdmreport_details.html', args => 'report_id:__id__', stype => 'free', slength => 6 },
      { name => 'name',          label => 'NAME',          desc => 'Name',              visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'free', slength => 50 },
      { name => 'label',         label => 'LABEL',         desc => 'Label',             visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'type',          label => 'TYPE',          desc => 'Type',              visible => 0, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'script_id',     label => 'SCRIPT',        desc => 'Script ID',         visible => 1, numeric => 1, index => 4,  type => 'id', url => 'histscript_details.html', args => 'script_id:__id__', stype => 'free', slength => 6 },
      { name => 'rmode',         label => 'MODE',          desc => 'Mode',              visible => 0, numeric => 0, index => 7,  type => 'string', stype => 'list' },
      { name => 'project',       label => 'PROJECT',       desc => 'Project',           visible => 1, numeric => 0, index => 12, type => 'string', stype => 'list' },
      { name => 'entity',        label => 'ENTITY',        desc => 'Entity',            visible => 1, numeric => 0, index => 13, type => 'string', stype => 'list' },
      { name => 'runtype',       label => 'RUNTYPE',       desc => 'Run Type',          visible => 1, numeric => 0, index => 14, type => 'string', stype => 'list' },
      { name => 'starttime',     label => 'START TIME',    desc => 'Start Time',        visible => 1, numeric => 1, index => 8,  type => 'timestamp' },
      { name => 'endtime',       label => 'END TIME',      desc => 'End Time',          visible => 1, numeric => 1, index => 9,  type => 'timestamp' },
      { name => 'size',          label => 'SIZE',          desc => 'Size',              visible => 1, numeric => 1, index => 10, type => 'bytes'     },
      { name => 'nr_records',    label => '# RECORDS',     desc => 'Number of Records', visible => 1, numeric => 1, index => 11, type => 'count' },
      { name => 'business_date', label => 'BUSINESS DATE', desc => 'Business Date',     visible => 0, numeric => 0, index => 15, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#------------------#
sub histwebcommand {
#------------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Web Command';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '70%';
    $HTML::Mason::Commands::table_name      = 'webcommands';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_webcommands;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_webcommand;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',            label => 'ID',        desc => 'ID',            visible => 1, numeric => 1, index => 1,  type => 'id', url => 'logfile2.html?name=' . $config->WEBLOGDIR . '/__id__.log', stype => 'free', slength => 6 },
      { name => 'starttime',     label => 'TIMESTAMP', desc => 'Timestamp',     visible => 1, numeric => 1, index => 5,  type => 'timestamp' },
      { name => 'win_user',      label => 'USER',      desc => 'User',          visible => 1, numeric => 0, index => 4,  type => 'win_user',  stype => 'list' },
      { name => 'cmdline',       label => 'COMMAND',   desc => 'Command',       visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'business_date', label => '',          desc => 'Business Date', visible => 0, numeric => 1, index => 6,  type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#--------------#
sub histscript {
#--------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Perl Script';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '70%';
    $HTML::Mason::Commands::table_name      = 'scripts';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_scripts;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_script;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',              label => 'ID',            desc => 'ID',            visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histscript_details.html', args => 'script_id:__id__', stype => 'free', slength => 6 },
      { name => 'hostname',        label => 'HOSTNAME',      desc => 'Hostname',      visible => 1, numeric => 0, index => 5,  type => 'hostname', stype => 'list' },
      { name => 'scriptname',      label => 'SCRIPT NAME',   desc => 'Script Name',   visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'path',            label => 'PATH',          desc => 'Path',          visible => 0, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'cmdline',         label => 'CMDLINE',       desc => 'Commandline',   visible => 0, numeric => 0, index => 4,  type => 'string' },
      { name => 'pid',             label => 'PID',           desc => 'PID',           visible => 0, numeric => 1, index => 6,  type => 'string', stype => 'free', slength => 6 },
      { name => 'username',        label => 'USER',          desc => 'Unix User',     visible => 0, numeric => 0, index => 7,  type => 'string', stype => 'list' },
      { name => 'project',         label => 'PROJECT',       desc => 'Project',       visible => 1, numeric => 0, index => 11, type => 'string', stype => 'list' },
      { name => 'sched_jobstream', label => 'STREAM',        desc => 'Jobstream',     visible => 1, numeric => 0, index => 12, type => 'string', stype => 'list' },
      { name => 'name',            label => 'NAME',          desc => 'Name',          visible => 1, numeric => 0, index => 19, type => 'string', stype => 'list' },
      { name => 'starttime',       label => 'START TIME',    desc => 'Start Time',    visible => 1, numeric => 1, index => 8,  type => 'timestamp' },
      { name => 'endtime',         label => 'END TIME',      desc => 'End Time',      visible => 1, numeric => 1, index => 9,  type => 'timestamp' },
      { name => 'duration',        label => 'DURATION',      desc => 'Duration',      visible => 1, numeric => 1, index => 14, type => 'seconds'   },
      { name => 'cpu_seconds',     label => 'CPUSEC',        desc => 'CPU Seconds',   visible => 1, numeric => 1, index => 16, type => 'count'     },
      { name => 'vsize',           label => 'VSIZE',         desc => 'Memory Size',   visible => 1, numeric => 1, index => 17, type => 'kbytes'    },
      { name => 'exitcode',        label => 'EXITCODE',      desc => 'Exit Code',     visible => 1, numeric => 1, index => 10, type => 'exitcode', stype => 'list' },
      { name => 'killed',          label => 'KILLED',        desc => 'Killed',        visible => 0, numeric => 0, index => 15, type => 'boolean', stype => 'list' },
      { name => 'logfile',         label => 'LOGFILE',       desc => 'Logfile',       visible => 0, numeric => 0, index => 18, type => 'string'    },
      { name => 'business_date',   label => 'BUSINESS DATE', desc => 'Business Date', visible => 0, numeric => 0, index => 13, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#-----------------#
sub histstatement {
#-----------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Sybase Statement';
    $HTML::Mason::Commands::search_button   = ( $args{session_id} ) ? 0 : 1;
    $HTML::Mason::Commands::go_back_button  = ( $args{session_id} ) ? 1 : 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '100%';
    $HTML::Mason::Commands::table_name      = 'statements';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_statements;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_statement;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',              label => 'ID',            desc => 'ID',              visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histstatement_details.html', args => 'statement_id:__id__', stype => 'free', slength => 6 },
      { name => 'session_id',      label => 'SESSION',       desc => 'Session ID',      visible => 1, numeric => 1, index => 2,  type => 'id', url => 'histsession_details.html', args => 'session_id:__id__', stype => 'free', slength => 6 },
      { name => 'script_id',       label => 'SCRIPT',        desc => 'Script ID',       visible => 1, numeric => 1, index => 3,  type => 'id', url => 'histscript_details.html', args =>  'script_id:__id__', stype => 'free', slength => 6 },
      { name => 'service_id',      label => 'SERVICE',       desc => 'Service ID',      visible => 1, numeric => 1, index => 4,  type => 'id', url => 'histservice_details.html', args => 'service_id:__id__', stype => 'free', slength => 6 },
      { name => 'schema',          label => 'SCHEMA',        desc => 'Schema',          visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'list' },
      { name => 'username',        label => 'USER',          desc => 'Username',        visible => 0, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'sid',             label => 'SID',           desc => 'SID',             visible => 0, numeric => 1, index => 7,  type => 'string', stype => 'free', slength => 6 },
      { name => 'hostname',        label => 'HOSTNAME',      desc => 'Hostname',        visible => 1, numeric => 0, index => 8,  type => 'hostname', stype => 'list' },
      { name => 'osuser',          label => 'OS USER',       desc => 'OS User',         visible => 1, numeric => 0, index => 9,  type => 'string', stype => 'list' },
      { name => 'pid',             label => 'PID',           desc => 'PID',             visible => 1, numeric => 1, index => 10, type => 'string', stype => 'free', slength => 6 },
      { name => 'program',         label => 'PROGRAM',       desc => 'Program',         visible => 1, numeric => 0, index => 11, type => 'string', stype => 'list' },
      { name => 'command',         label => 'COMMAND',       desc => 'Command',         visible => 1, numeric => 0, index => 12,  type => 'string', stype => 'list' },
      { name => 'starttime',       label => 'START TIME',    desc => 'Start Time',      visible => 1, numeric => 1, index => 13, type => 'timestamp' },
      { name => 'endtime',         label => 'END TIME',      desc => 'End Time',        visible => 1, numeric => 1, index => 14, type => 'timestamp' },
      { name => 'duration',        label => 'DURATION',      desc => 'Duration',        visible => 1, numeric => 1, index => 15, type => 'seconds'   },
      { name => 'cpu',             label => 'CPU',           desc => 'CPU',             visible => 1, numeric => 1, index => 16, type => 'count', threshold => $config->DB_THRESHOLD_CPU },
      { name => 'wait_time',       label => 'WAIT TIME',     desc => 'Wait Time',       visible => 1, numeric => 1, index => 17, type => 'count' },
      { name => 'logical_reads',   label => 'LREADS',        desc => 'Logical Reads',   visible => 1, numeric => 1, index => 18, type => 'count', threshold => $config->DB_THRESHOLD_LOGICAL_READS },
      { name => 'physical_reads',  label => 'PREADS',        desc => 'Physical Reads',  visible => 1, numeric => 1, index => 19, type => 'count', threshold => $config->DB_THRESHOLD_PHYSICAL_READS },
      { name => 'physical_writes', label => 'PWRITES',       desc => 'Physical Writes', visible => 1, numeric => 1, index => 20, type => 'count', threshold => $config->DB_THRESHOLD_PHYSICAL_WRITES },
      { name => 'sql_tag',         label => 'SQL TAG',       desc => 'SQL Tag',         visible => 1, numeric => 0, index => 21, type => 'string', stype => 'free', slength => 10 },
      { name => 'plan_tag',        label => 'PLAN TAG',      desc => 'Plan Tag',        visible => 1, numeric => 0, index => 22, type => 'string', stype => 'free', slength => 10 },
      { name => 'business_date',   label => 'BUSINESS DATE', desc => 'Business Date',   visible => 0, numeric => 0, index => 23, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#---------------#
sub histblocker {
#---------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Sybase Blocker';
    $HTML::Mason::Commands::search_button   = ( $args{statement_id} ) ? 0 : 1;
    $HTML::Mason::Commands::go_back_button  = ( $args{statement_id} ) ? 1 : 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'blockers';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_blockers;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_blocker;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',              label => 'ID',                desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histblocker_details.html', args => 'blocker_id:__id__', stype => 'free', slength => 6 },
      { name => 'statement_id',    label => 'BLOCKED STATEMENT', desc => 'Blocked Statement', visible => 1, numeric => 1, index => 2,  type => 'id', url => 'histstatement_details.html', args => 'statement_id:__id__', stype => 'free', slength => 6 },
      { name => 'spid',            label => 'SPID',              desc => 'SPID',              visible => 1, numeric => 1, index => 3,  type => 'string', stype => 'free', slength => 6 },
      { name => 'db_name',         label => 'DB NAME',           desc => 'Database Name',     visible => 1, numeric => 0, index => 4,  type => 'string', stype => 'list' },
      { name => 'login',           label => 'LOGIN',             desc => 'Login',             visible => 1, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'hostname',        label => 'HOSTNAME',          desc => 'Hostname',          visible => 1, numeric => 0, index => 7,  type => 'hostname', stype => 'list' },
      { name => 'pid',             label => 'PID',               desc => 'PID',               visible => 1, numeric => 1, index => 5,  type => 'string', stype => 'free', slength => 6 },
      { name => 'application',     label => 'APPLICATION',       desc => 'Application',       visible => 1, numeric => 0, index => 8,  type => 'string', stype => 'list' },
      { name => 'tran_name',       label => 'TRANSACTION',       desc => 'Transaction',       visible => 1, numeric => 0, index => 9,  type => 'string', stype => 'list' },
      { name => 'cmd',             label => 'COMMAND',           desc => 'Command',           visible => 1, numeric => 0, index => 10, type => 'string', stype => 'list' },
      { name => 'status',          label => 'STATUS',            desc => 'Status',            visible => 1, numeric => 0, index => 11, type => 'string', stype => 'list' },
      { name => 'starttime',       label => 'START TIME',        desc => 'Start Time',        visible => 1, numeric => 1, index => 12, type => 'timestamp' },
      { name => 'duration',        label => 'DURATION',          desc => 'Duration',          visible => 1, numeric => 1, index => 13, type => 'seconds'   },
      { name => 'sql_tag',         label => 'SQL TAG',           desc => 'SQL Tag',           visible => 0, numeric => 0, index => 15, type => 'string'    },
      { name => 'business_date',   label => 'BUSINESS DATE',     desc => 'Business Date',     visible => 0, numeric => 0, index => 16, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#------------#
sub histcore {
#------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Core Dump';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'cores';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_cores;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_core;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',              label => 'ID',            desc => 'ID',            visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histcore_details.html', args => 'core_id:__id__', stype => 'free', slength => 6 },
      { name => 'timestamp',       label => 'TIMESTAMP',     desc => 'Timestamp',     visible => 1, numeric => 1, index => 8,  type => 'timestamp' },
      { name => 'session_id',      label => 'SESSION',       desc => 'Session ID',    visible => 1, numeric => 1, index => 2,  type => 'id', url => 'histsession_details.html', args => 'session_id:__id__', stype => 'free', slength => 6 },
      { name => 'pstack_path',     label => 'STACKTRACE',    desc => 'Stack Trace',   visible => 0, numeric => 0, index => 3,  type => 'string' },
      { name => 'pmap_path',       label => 'MEMORY MAP',    desc => 'Memory Map',    visible => 0, numeric => 0, index => 4,  type => 'string' },
      { name => 'core_path',       label => 'COREFILE',      desc => 'Core File',     visible => 0, numeric => 0, index => 5,  type => 'string' },
      { name => 'hostname',        label => 'HOSTNAME',      desc => 'Hostname',      visible => 0, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'size',            label => 'SIZE',          desc => 'Size',          visible => 0, numeric => 1, index => 7,  type => 'bytes' },
      { name => 'win_user',        label => 'USER',          desc => 'Windows User',  visible => 1, numeric => 0, index => 9,  type => 'win_user', stype => 'list' },
      { name => 'mx_user',         label => 'MX USER',       desc => 'Murex User',    visible => 1, numeric => 0, index => 10, type => 'string', stype => 'list' },
      { name => 'mx_group',        label => 'MX GROUP',      desc => 'Murex Group',   visible => 1, numeric => 0, index => 11, type => 'string', stype => 'list' },
      { name => 'mx_nick',         label => 'Nick',          desc => 'Murex Nick',    visible => 0, numeric => 0, index => 12, type => 'string', stype => 'list' },
      { name => 'function',        label => 'FUNCTION',      desc => 'Function',      visible => 1, numeric => 0, index => 13, type => 'string', stype => 'list' },
      { name => 'business_date',   label => 'BUSINESS DATE', desc => 'Business Date', visible => 0, numeric => 0, index => 14, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#----------------#
sub histtransfer {
#----------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'ConnectDirect Transfer';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'transfers';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_transfers;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_transfer;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',               label => 'ID',            desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histtransfer_details.html', args => 'transfer_id:__id__', stype => 'free', slength => 6 },
      { name => 'hostname',         label => 'HOSTNAME',      desc => 'Hostname',          visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'project',          label => 'PROJECT',       desc => 'Project',           visible => 1, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'sched_jobstream',  label => 'STREAM',        desc => 'Jobstream',         visible => 1, numeric => 0, index => 4,  type => 'string', stype => 'list' },
      { name => 'entity',           label => 'ENTITY',        desc => 'Entity',            visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'list' },
      { name => 'content',          label => 'CONTENT',       desc => 'Content',           visible => 1, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'target',           label => 'TARGET',        desc => 'Target',            visible => 1, numeric => 0, index => 7,  type => 'string', stype => 'list' },
      { name => 'starttime',        label => 'START TIME',    desc => 'Start Time',        visible => 1, numeric => 1, index => 8,  type => 'timestamp' },
      { name => 'endtime',          label => 'END TIME',      desc => 'End Time',          visible => 1, numeric => 1, index => 9,  type => 'timestamp' },
      { name => 'duration',         label => 'DURATION',      desc => 'Duration',          visible => 1, numeric => 1, index => 10, type => 'seconds'   },
      { name => 'filelength',       label => '# RECORDS',     desc => 'Number of records', visible => 1, numeric => 1, index => 11, type => 'count'     },
      { name => 'reruns',           label => '# RR',          desc => 'Number of reruns',  visible => 1, numeric => 1, index => 12, type => 'count', threshold => 1, stype => 'list' },
      { name => 'killed',           label => 'KILLED',        desc => 'Killed',            visible => 0, numeric => 0, index => 13, type => 'boolean', stype => 'list' },
      { name => 'exitcode',         label => 'EXITCODE',      desc => 'Exitcode',          visible => 1, numeric => 1, index => 14, type => 'exitcode', stype => 'list' },
      { name => 'cmdline',          label => 'CMDLINE',       desc => 'Commandline',       visible => 0, numeric => 0, index => 15, type => 'string' },
      { name => 'pid',              label => 'PID',           desc => 'PID',               visible => 0, numeric => 1, index => 16, type => 'string', stype => 'free', slength => 6 },
      { name => 'cdpid',            label => 'CD PID',        desc => 'C:D PID',           visible => 0, numeric => 1, index => 17, type => 'string', stype => 'free', slength => 6 },
      { name => 'username',         label => 'USER',          desc => 'Unix User',         visible => 0, numeric => 0, index => 18, type => 'string', stype => 'list' },
      { name => 'business_date',    label => 'BUSINESS DATE', desc => 'Business Date',     visible => 0, numeric => 0, index => 19, type => 'string', stype => 'list' },
      { name => 'logfile',          label => 'LOGFILE',       desc => 'Logfile',           visible => 0, numeric => 0, index => 20, type => 'string' },
      { name => 'cdkeyfile',        label => 'KEYFILE',       desc => 'C:D Keyfile',       visible => 0, numeric => 0, index => 21, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#---------------#
sub histreport {
#---------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'M-Report';
    $HTML::Mason::Commands::search_button   = ( $args{session_id} ) ? 0 : 1;
    $HTML::Mason::Commands::go_back_button  = ( $args{session_id} ) ? 1 : 0;
    $HTML::Mason::Commands::refresh_button  = 0;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'reports';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_reports;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_report;

    @HTML::Mason::Commands::columns         = (
      { name => 'id',               label => 'ID',            desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histreport_details.html', args => 'report_id:__id__', stype => 'free', slength => 6 },
      { name => 'label',            label => 'LABEL',         desc => 'Label',             visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'type',             label => 'TYPE',          desc => 'Report Type',       visible => 0, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'session_id',       label => 'SESSION',       desc => 'Session ID',        visible => 0, numeric => 1, index => 4,  type => 'id', url => 'histsession_details.html', args => 'session_id:__id__', stype => 'free', slength => 6 },
      { name => 'batchname',        label => 'BATCH',         desc => 'Batch Name',        visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'list' },
      { name => 'reportname',       label => 'REPORT',        desc => 'Report Name',       visible => 0, numeric => 0, index => 6,  type => 'string', stype => 'list' },
      { name => 'entity',           label => 'ENTITY',        desc => 'Entity',            visible => 1, numeric => 0, index => 7,  type => 'string', stype => 'list' },
      { name => 'runtype',          label => 'RUNTYPE',       desc => 'Run Type',          visible => 0, numeric => 0, index => 8,  type => 'string', stype => 'list' },
      { name => 'mds',              label => 'MDS',           desc => 'Market Data Set',   visible => 0, numeric => 0, index => 9,  type => 'string', stype => 'list' },
      { name => 'starttime',        label => 'START TIME',    desc => 'Start Time',        visible => 1, numeric => 1, index => 10, type => 'timestamp' },
      { name => 'endttime',         label => 'END TIME',      desc => 'End Time',          visible => 1, numeric => 1, index => 11, type => 'timestamp' },
      { name => 'duration',         label => 'DURATION',      desc => 'Duration',          visible => 1, numeric => 1, index => 17, type => 'seconds'   },
      { name => 'size',             label => 'SIZE',          desc => 'Size',              visible => 1, numeric => 1, index => 12, type => 'bytes'     },
      { name => 'nr_records',       label => '# RECORDS',     desc => 'Number of records', visible => 1, numeric => 1, index => 13, type => 'count'     },
      { name => 'tablename',        label => 'TABLE',         desc => 'Table Name',        visible => 1, numeric => 0, index => 14, type => 'table'     },
      { name => 'path',             label => 'PATH',          desc => 'Report Path',       visible => 1, numeric => 0, index => 15, type => 'report'    },
      { name => 'business_date',    label => 'BUSINESS DATE', desc => 'Business Date',     visible => 0, numeric => 0, index => 16, type => 'string', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#---------------#
sub histmessage {
#---------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Message';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '70%';
    $HTML::Mason::Commands::table_name      = 'messages';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_messages;
    $HTML::Mason::Commands::details_method  = undef;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',            label => 'ID',           desc => 'ID',            visible => 1, numeric => 1, index => 1,  type => 'id', ajax_url => 'histmessage_details2.html', stype => 'free', slength => 6 },
      { name => 'type',          label => 'TYPE',         desc => 'Type',          visible => 0, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'timestamp',     label => 'TIMESTAMP',    desc => 'Timestamp',     visible => 1, numeric => 1, index => 6,  type => 'timestamp' },
      { name => 'priority',      label => 'PRIORITY',     desc => 'Priority',      visible => 1, numeric => 0, index => 3,  type => 'string',   stype => 'list' },
      { name => 'environment',   label => 'ENVIRONMENT',  desc => 'Environment',   visible => 1, numeric => 0, index => 4,  type => 'string',   stype => 'list' },
      { name => 'destination',   label => 'DESTINATION',  desc => 'Destination',   visible => 1, numeric => 0, index => 5,  type => 'string',   stype => 'list' },
      { name => 'validity',      label => 'VALIDITY',     desc => 'Validity',      visible => 1, numeric => 1, index => 7,  type => 'seconds' },
      { name => 'message',       label => 'MESSAGE',      desc => 'Message',       visible => 1, numeric => 0, index => 8,  type => 'string' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#-------------#
sub md_upload {
#-------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Market Data Upload';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'md_uploads';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_md_uploads;
    $HTML::Mason::Commands::details_method  = \&Mx::DBaudit::retrieve_md_upload;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',              label => 'ID',             desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'id', url => 'histdetails.html', args => 'object:\'md_upload\', id:__id__', stype => 'free', slength => 6 },
      { name => 'timestamp',       label => 'TIMESTAMP',      desc => 'Timestamp',         visible => 1, numeric => 1, index => 2,  type => 'timestamp' },
      { name => 'type',            label => 'TYPE',           desc => 'Type',              visible => 0, numeric => 0, index => 3,  type => 'string', stype => 'list' },
      { name => 'channel',         label => 'CHANNEL',        desc => 'Channel',           visible => 1, numeric => 0, index => 4,  type => 'string', stype => 'list' },
      { name => 'status',          label => 'STATUS',         desc => 'Status',            visible => 1, numeric => 0, index => 5,  type => 'string', stype => 'list' },
      { name => 'nr_not_imported', label => '# NOT IMPORTED', desc => '# Not Imported',    visible => 1, numeric => 1, index => 6,  type => 'count' },
      { name => 'xml_path',        label => 'XML',            desc => 'XML File',          visible => 0, numeric => 0, index => 7,  type => 'xml_file' },
      { name => 'xml_size',        label => 'XML SIZE',       desc => 'XML Size',          visible => 1, numeric => 1, index => 8,  type => 'bytes' },
      { name => 'win_user',        label => 'USER',           desc => 'User',              visible => 1, numeric => 0, index => 9,  type => 'win_user', stype => 'list' },
      { name => 'md_group',        label => 'GROUP',          desc => 'Group',             visible => 1, numeric => 0, index => 10, type => 'string', stype => 'list' },
      { name => 'action',          label => 'ACTION',         desc => 'Action',            visible => 1, numeric => 0, index => 11, type => 'string', stype => 'list' },
      { name => 'md_date',         label => 'DATE',           desc => 'Date',              visible => 1, numeric => 0, index => 12, type => 'string', stype => 'list' },
      { name => 'mds',             label => 'MDS',            desc => 'Market Data Set',   visible => 1, numeric => 0, index => 13, type => 'string', stype => 'list' },
      { name => 'script_id',       label => 'SCRIPT',         desc => 'Script ID',         visible => 1, numeric => 1, index => 14, type => 'id', url => 'histscript_details.html', args => 'script_id:__id__', stype => 'free', slength => 6 },
      { name => 'session_id',      label => 'SESSION',        desc => 'Session ID',        visible => 1, numeric => 1, index => 15, type => 'id', url => 'histsession_details.html', args => 'session_id:__id__', stype => 'free', slength => 6 },
      { name => 'md_pair',         label => 'PAIRS',          desc => 'Currency pairs',    visible => 0, numeric => 0, index => 16, type => 'array' },
      { name => 'vol_matrix',      label => 'MATRIX',         desc => 'Volatility Matrix', visible => 1, numeric => 0, index => 7,  type => 'link', url => 'vol_matrix.html', args => 'xml_path:\'__value__\'', url_label => 'Display' }, 
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#---------------#
sub histimstatus {
#---------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Historical IntelliMatch SWIFT status';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '80%';
    $HTML::Mason::Commands::table_name      = 'imswift_status';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_swiftstatuses;
    $HTML::Mason::Commands::detail_method   = \&Mx::DBaudit::retrieve_swiftstatus;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',               label => 'ID',                  desc => 'ID',                      visible => 1, numeric => 1, index => 1,  type => 'string' },
      { name => 'sendersref',       label => 'SENDERS REF',         desc => 'Sender Reference',        visible => 1, numeric => 0, index => 2,  type => 'string' },
      { name => 'relatedref',       label => 'RELATED REF',         desc => 'Related Reference',       visible => 1, numeric => 0, index => 3,  type => 'string' },
      { name => 'messagetype',      label => 'MSG TYPE',            desc => 'Message Type',            visible => 1, numeric => 0, index => 4,  type => 'string' },
      { name => 'reasoncode',       label => 'REASONCODE',          desc => 'Reason Code',             visible => 1, numeric => 0, index => 5,  type => 'string' },
      { name => 'account',          label => 'ACCOUNT',             desc => 'Account',                 visible => 1, numeric => 0, index => 6,  type => 'string' },
      { name => 'itemstate',        label => 'ITEM STATE',          desc => 'Item State',              visible => 1, numeric => 0, index => 7,  type => 'string' },
      { name => 'state',            label => 'STATE',               desc => 'State',                   visible => 1, numeric => 0, index => 8,  type => 'string' },
      { name => 'operationtype',    label => 'OPERATION',           desc => 'Operation',               visible => 1, numeric => 0, index => 9,  type => 'string' },
      { name => 'eventtype',        label => 'EVENT',               desc => 'Event',                   visible => 1, numeric => 0, index => 10, type => 'string' },
      { name => 'passnum',          label => 'PASS NUM',            desc => 'Pass Num',                visible => 1, numeric => 1, index => 11, type => 'string' },
      { name => 'swapsendersref',   label => 'SWAP SENDERS REF',    desc => 'Swap Senders Ref',        visible => 1, numeric => 0, index => 12, type => 'string' },
      { name => 'swapitemtype',     label => 'SWAP ITEM TYPE',      desc => 'Swap Item Type',          visible => 1, numeric => 0, index => 13, type => 'string' },
      { name => 'timestamp',        label => 'TIMESTAMP',           desc => 'Timestamp',               visible => 1, numeric => 1, index => 14, type => 'timestamp' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#---------------#
sub histruntime {
#---------------#
    my ( $class, %args ) = @_;


    $HTML::Mason::Commands::description     = 'Runtime';
    $HTML::Mason::Commands::search_button   = 1;
    $HTML::Mason::Commands::go_back_button  = 0;
    $HTML::Mason::Commands::refresh_button  = 1;
    $HTML::Mason::Commands::table_width     = '50%';
    $HTML::Mason::Commands::table_name      = 'runtimes';
    $HTML::Mason::Commands::list_method     = \&Mx::DBaudit::retrieve_runtimes;
    $HTML::Mason::Commands::details_method  = undef;
    @HTML::Mason::Commands::columns         = (
      { name => 'id',               label => 'ID',            desc => 'ID',                visible => 1, numeric => 1, index => 1,  type => 'string' },
      { name => 'descriptor',       label => 'LABEL',         desc => 'Label',             visible => 1, numeric => 0, index => 2,  type => 'string', stype => 'list' },
      { name => 'starttime',        label => 'START TIME',    desc => 'Start Time',        visible => 1, numeric => 1, index => 3,  type => 'timestamp' },
      { name => 'endtime',          label => 'END TIME',      desc => 'End Time',          visible => 1, numeric => 1, index => 4,  type => 'timestamp' },
      { name => 'duration',         label => 'DURATION',      desc => 'Duration',          visible => 1, numeric => 1, index => 5,  type => 'seconds'   },
      { name => 'exitcode',         label => 'EXITCODE',      desc => 'Exitcode',          visible => 1, numeric => 1, index => 6,  type => 'exitcode', stype => 'list' },
    );

    %HTML::Mason::Commands::columns = _hashify( @HTML::Mason::Commands::columns );
}

#------------#
sub _hashify {
#------------#
    my ( @columns ) = @_;

   
    my %columns;

    foreach my $column ( @columns ) {
        my $name = $column->{name};
        $columns{ $name } = $column;
    }

    return %columns;
}

1;
