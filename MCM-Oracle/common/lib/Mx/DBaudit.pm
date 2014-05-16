package Mx::DBaudit;

use strict;

use Mx::Env;
use Mx::Log;
use Mx::Config;
use Mx::Account;
use Mx::Oracle;
use Mx::Murex;
use Mx::Scheduler;
use Mx::Util;
use Carp;
use IO::File;
use File::Copy;
use Time::Local;
use Storable qw( freeze thaw );
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of DBaudit (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    $self->{config} = $config;

    my $account = Mx::Account->new( name => $config->MON_DBUSER, config => $config, logger => $logger );

    my $database = $args{database} || $config->DB_MON;

    my $oracle = Mx::Oracle->new( database => $database, username => $account->name, password => $account->password, logger => $logger, config => $config );

    unless ( $oracle->open() ) {
        $logger->logdie("unable to connect to monitoring database $database");
    }

    $self->{oracle} = $oracle;

    bless $self, $class;
}

#---------#
sub close {
#---------#
    my ( $self ) = @_;


    $self->{oracle}->close();
}

#----------#
sub reopen {
#----------#
    my ( $self ) = @_;


    unless ( $self->{oracle}->open() ) {
        $self->{logger}->logdie("unable to re-connect to monitoring database");
    }
}

#----------#
sub oracle {
#----------#
    my ( $self ) = @_;

    return $self->{oracle};
}

#
# Arguments
#
# cmdline
# hostname
# mx_scripttype
# mx_scriptname
# win_user
# mx_client_host
# ab_session_id
#
#----------------------------#
sub record_session_req_start {
#----------------------------#
    my ( $self, %args ) = @_;


    my $cmdline         = substr( _compress_cmdline( $args{cmdline}, $self->{config} ), 0, 3600 );
    my $hostname        = $args{hostname};
    my $starttime       = time();
    my $mx_scripttype   = $args{mx_scripttype} || 'user session';
    my $mx_scriptname   = $args{mx_scriptname};
    my $mx_nick         = $args{mx_nick};
    my $win_user        = $args{win_user};
    my $mx_client_host  = $args{mx_client_host};
    my $ab_session_id   = $args{ab_session_id} || 0;
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity};
    my $runtype         = $args{runtype};
    my $project         = $args{project};
    my $remote_delay    = ( defined $args{remote_delay} ) ? $args{remote_delay} : undef;
#    my $business_date   = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date   = Mx::Murex->calendardate();

    my $statement = 'insert into sessions (id, hostname, cmdline, req_starttime, mx_scripttype, mx_scriptname, mx_nick, win_user, mx_client_host, ab_session_id, sched_jobstream, entity, runtype, business_date, project, reruns, remote_delay ) values ( sessions_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $hostname, $cmdline, $starttime, $mx_scripttype, $mx_scriptname, $mx_nick, $win_user, $mx_client_host, $ab_session_id, $sched_jobstream, $entity, $runtype, $business_date, $project, 0, $remote_delay ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#--------------------#
sub record_milestone {
#--------------------#
    my ( $self, %args ) = @_;


    my $timestamp       = time();
    my $name            = $args{name};
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity};
    my $runtype         = $args{runtype};
    my $project         = $args{project};
#    my $business_date   = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date   = Mx::Murex->calendardate();

    my $statement = 'insert into sessions (id, hostname, cmdline, req_starttime, mx_starttime, mx_endtime, req_endtime, mx_scripttype, mx_scriptname, exitcode, sched_jobstream, entity, runtype, business_date, project) values ( sessions_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ '', '', $timestamp, $timestamp, $timestamp, $timestamp, 'milestone', $name, 0, $sched_jobstream, $entity, $runtype, $business_date, $project ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#--------------------------#
sub record_milestone_start {
#--------------------------#
    my ( $self, %args ) = @_;


    my $timestamp       = time();
    my $name            = $args{name};
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity};
    my $runtype         = $args{runtype};
    my $project         = $args{project};
#    my $business_date   = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date   = Mx::Murex->calendardate();

    my $statement = 'insert into sessions (id, hostname, cmdline, req_starttime, mx_starttime, mx_scripttype, mx_scriptname, sched_jobstream, entity, runtype, business_date, project) values ( sessions_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ '', '', $timestamp, $timestamp, 'milestone', $name, $sched_jobstream, $entity, $runtype, $business_date, $project ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#------------------------#
sub record_milestone_end {
#------------------------#
    my ( $self, %args ) = @_;


    my $timestamp       = time();
    my $name            = $args{name};
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity} || Mx::Scheduler->entity( $sched_jobstream );

    my $query = "select id from sessions where mx_scripttype = ? and mx_scriptname = ? and entity = ? and mx_endtime is null and req_endtime is null order by id desc";

    my $result = $self->{oracle}->query( query => $query, values => [ 'milestone', $name, $entity ] );

    if ( ! $result->next ) {
        $self->{logger}->warn('no milestone start found, going for singular milestone recording');
        $self->record_milestone( %args );
    }
    else {
        my $id = $result->nextref->[0];

        my $statement = "update sessions set mx_endtime = ?, req_endtime = ?, exitcode = ? where id = ?";

        unless ( $self->{oracle}->do( statement => $statement, values => [ $timestamp, $timestamp, 0, $id ] ) ) { 
            $self->{logger}->error("could not update milestone start with id $id");
        }
    }
}

#
# Arguments
#
# cmdline
# hostname
# mx_scripttype
# mx_scriptname
# win_user
# mx_client_host
#
#---------------------------#
sub record_session_mx_start {
#---------------------------#
    my ( $self, %args ) = @_;

    my $sybase         = $self->{sybase};
    my $cmdline        = _compress_cmdline( $args{cmdline}, $self->{config} );
    $cmdline           = substr( $cmdline, 0, 3600 );
    my $hostname       = $args{hostname};
    my $mx_starttime   = $args{mx_starttime};
    my $mx_scripttype  = $args{mx_scripttype} || 'user session';
    my $mx_scriptname  = $args{mx_scriptname};
    my $mx_nick        = $args{mx_nick};
    my $win_user       = $args{win_user};
    my $mx_client_host = $args{mx_client_host};
#    my $business_date  = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} ) || '-';
    my $business_date  = Mx::Murex->calendardate() || '-';

    my $statement = "insert into sessions (id, hostname, cmdline, mx_starttime, mx_scripttype, mx_scriptname, mx_nick, win_user, mx_client_host, business_date) values (sessions_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O";

    my $values = [ $hostname, $cmdline, $mx_starttime, $mx_scripttype, $mx_scriptname, $mx_nick, $win_user, $mx_client_host, $business_date ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#-----------------------#
sub retrieve_client_map {
#-----------------------#
    my ( $self, %args ) = @_;


    my %map = ();
    my $query  = "select mx_client_host, win_user, count(win_user) as cnt from sessions where win_user <> '' group by win_user, mx_client_host order by mx_client_host, cnt desc";
    my $result = $self->{oracle}->query( query => $query );

    return unless $result;

    while ( my ( $host, $user, $cnt ) = $result->next ) {
        if ( my $list = $map{$host} ) {
            push @{$list}, "$user:$cnt";
        }
        else {
            $map{$host} = [ "$user:$cnt" ];
        }
    }

    return %map;
}

#
# Arguments
#
# cmdline
# hostname
#
#---------------------------#
sub record_ab_session_start {
#---------------------------#
    my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
    my $cmdline         = substr( $args{cmdline}, 0, 3600);
    my $hostname        = $args{hostname};
    my $starttime       = time();
#    my $business_date   = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date   = Mx::Murex->calendardate();
    my $sched_jobstream = $args{sched_jobstream};
    my $batchname       = $args{batchname};
    my $pid             = $args{pid};
    my $statement = "insert into ab_sessions (hostname, cmdline, starttime, business_date, sched_jobstream, batchname, pid) values ('$hostname', '$cmdline', $starttime, '$business_date', '$sched_jobstream', '$batchname', $pid)";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#------------------------#
sub record_scanner_start {
#------------------------#
    my ( $self, %args ) = @_;


    my $pid           = $args{pid};
    my $hostname      = $args{hostname};
    my $mx_nick       = $args{mx_nick};
    my $business_date = Mx::Murex->calendardate();

    my $query = 'select id from sessions where pid = ? and rtrim(hostname) = ? and mx_nick = ? and business_date = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $pid, $hostname, $mx_nick, $business_date ] );

    my $session_id = $result->nextref->[0];

    return unless $session_id;

    my $parent_id       = $args{parent_id};
    my $mx_scripttype   = $args{mx_scripttype};
    my $mx_scriptname   = $args{mx_scriptname};
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity};
    my $runtype         = $args{runtype};
    my $project         = $args{project};

    my $statement = 'update sessions set ab_session_id = ?, mx_scripttype = ?, mx_scriptname = ?, sched_jobstream = ?, entity = ?, runtype = ?, project = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $parent_id, $mx_scripttype, $mx_scriptname, $sched_jobstream, $entity, $runtype, $project, $session_id ] );

    return $session_id;
}

#-----------------------#
sub record_script_start {
#-----------------------#
    my ( $self, %args ) = @_;


    my $scriptname      = $args{scriptname};
    my $path            = $args{path};
    my $cmdline         = $args{cmdline};
    $cmdline            = substr( $cmdline, 0, 500 );
    my $hostname        = $args{hostname};
    my $pid             = $args{pid};
    my $username        = $args{username};
    my $starttime       = $args{starttime};
    my $project         = $args{project};
    my $sched_jobstream = $args{sched_jobstream};
    my $logfile         = $args{logfile};
    my $name            = $args{name};
#    my $business_date  = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} ) || '-';
    my $business_date   = Mx::Murex->calendardate() || '-';

    my $statement = 'insert into scripts (id, scriptname, path, cmdline, hostname, pid, username, starttime, project, sched_jobstream, logfile, business_date, name) values (scripts_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [$scriptname, $path, $cmdline, $hostname, $pid, $username, $starttime, $project, $sched_jobstream, $logfile, $business_date, $name];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#---------------------------#
sub record_webcommand_start {
#---------------------------#
    my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
    my $cmdline         = $args{cmdline};
    $cmdline            = substr( $cmdline, 0, 500 );
    my $win_user        = $args{win_user};
    my $starttime       = $args{starttime};
#    my $business_date  = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} ) || '-';
    my $business_date   = Mx::Murex->calendardate() || '-';
    my $statement = "insert into webcommands (cmdline, win_user, starttime, business_date) values ('$cmdline', '$win_user', $starttime, '$business_date')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#-------------------------#
sub record_transfer_start {
#-------------------------#
    my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
    my $hostname        = $args{hostname};
    my $project         = $args{project};
    my $sched_jobstream = $args{sched_jobstream};
    my $entity          = $args{entity};
    my $content         = $args{content};
    my $target          = $args{target};
    my $starttime       = time();
    my $filelength      = $args{filelength};
    my $cmdline         = $args{cmdline};
    my $pid             = $args{pid};
    my $cdpid           = $args{cdpid};
    my $username        = $args{username};
    my $business_date   = Mx::Murex->calendardate() || '-';
    my $logfile         = $args{logfile};
    my $cdkeyfile       = $args{cdkeyfile};

    my $statement       = "insert into transfers (hostname, project, sched_jobstream, entity, content, target, starttime, filelength, cmdline, pid, cdpid, username, business_date, logfile, cdkeyfile) values ('$hostname', '$project', '$sched_jobstream', '$entity', '$content', '$target', $starttime, $filelength, '$cmdline', $pid, $cdpid,  '$username', '$business_date', '$logfile', '$cdkeyfile')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#------------------------#
sub record_runtime_start {
#------------------------#
    my ( $self, %args ) = @_;

    my $sybase     = $self->{sybase};
    my $descriptor = $args{descriptor};
    my $starttime  = time();

    my $statement = "insert into runtimes (descriptor, starttime) values ('$descriptor', $starttime)";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#--------------------#
sub record_job_start {
#--------------------#
    my ( $self, %args ) = @_;


    my $name         = $args{name};
    my $status       = $args{status};
    my $next_runtime = $args{next_runtime};

    my $statement = 'insert into jobs (id, name, status, next_runtime) values (jobs_seq.nextval, ?, ?, ?) returning id into ?:O';

    my $values = [ $name, $status, $next_runtime ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}


#------------------#
sub record_tws_job {
#------------------#
    my ( $self, %args ) = @_;


    my $sybase       = $self->{sybase};
    my $name         = $args{name};
    my $jobstream    = $args{jobstream};
    my $username     = $args{username};
    my $workstation  = $args{workstation};
    my $plantime     = $args{plantime};
    my $command      = $args{command};
    my $remote       = $args{remote};
    my $instance     = $args{instance};
    my $nowait       = $args{nowait};
    my $project      = $args{project};
    my $scriptname   = $args{scriptname};
    my $timestamp    = $args{timestamp};

    $command =~ s/'/\\'/g;

    my $statement = "insert into tws_jobs (name, jobstream, username, workstation, plantime, command, remote, instance, nowait, project, scriptname, timestamp) values ('$name', '$jobstream', '$username', '$workstation', '$plantime', '$command', '$remote', '$instance', '$nowait', '$project', '$scriptname', $timestamp)";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity', quiet => 1 );
    return $result->[0][0];
}

#------------------#
sub update_tws_job {
#------------------#
    my ( $self, %args ) = @_;

    my $sybase       = $self->{sybase};
    my $id           = $args{id};
    my $plantime     = $args{plantime};
    my $command      = $args{command};
    my $remote       = $args{remote};
    my $instance     = $args{instance};
    my $nowait       = $args{nowait};
    my $project      = $args{project};
    my $scriptname   = $args{scriptname};
    my $timestamp    = $args{timestamp};

    my $statement = "update tws_jobs set plantime = ?, command = ?, remote = ?, instance = ?, nowait = ?, project = ?, scriptname = ?, timestamp = ? where id = ?";
    $sybase->do( statement => $statement, values => [ $plantime, $command, $remote, $instance, $nowait, $project, $scriptname, $timestamp, $id ] );
}

#--------------------#
sub retrieve_tws_job {
#--------------------#
    my ( $self, %args ) = @_;


    my $sybase    = $self->{sybase};
    my $name      = $args{name}; 
    my $jobstream = $args{jobstream}; 

    my $query = 'select id, name, jobstream, username, workstation, plantime, command, remote, instance, nowait, project, scriptname, timestamp from tws_jobs where name = ? and jobstream = ?';
    my $result = $sybase->query( query => $query, values => [ $name, $jobstream ], quiet => 1 );

    return unless $result;

    return $result->[0];
}

#---------------------#
sub retrieve_tws_jobs {
#---------------------#
    my ( $self, %args ) = @_;


    my $sybase = $self->{sybase};

    my $query = 'select id, name, jobstream, username, workstation, plantime, command, remote, instance, nowait, project, scriptname, timestamp from tws_jobs';
    my $result = $sybase->query( query => $query, quiet => 1 );

    return unless $result;

    return $result;
}

#------------------------#
sub record_tws_execution {
#------------------------#
    my ( $self, %args ) = @_;


    my $sybase        = $self->{sybase};
    my $tws_job_id    = $args{tws_job_id};
    my $mode          = $args{mode};
    my $starttime     = $args{starttime};
    my $plan_date     = $args{plan_date};
    my $tws_date      = $args{tws_date};
    my $job_nr        = $args{job_nr};
    my $business_date = Mx::Murex->calendardate();

    my $statement = "insert into tws_executions (tws_job_id, mode, starttime, plan_date, tws_date, business_date, job_nr) values ($tws_job_id, '$mode', $starttime, '$plan_date', '$tws_date', '$business_date', '$job_nr')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity', quiet => 1 );
    return $result->[0][0];
}

#------------------------#
sub update_tws_execution {
#------------------------#
    my ( $self, %args ) = @_;

    my $sybase       = $self->{sybase};
    my $id           = $args{id};
    my $endtime      = $args{endtime};
    my $exitcode     = $args{exitcode};
    my $stdout       = $args{stdout};

    my $statement = "update tws_executions set endtime = ?, exitcode = ?, stdout = ? where id = ?";
    $sybase->do( statement => $statement, values => [ $endtime, $exitcode, $stdout, $id ] );
}

#---------------------------#
sub retrieve_tws_executions {
#---------------------------#
    my ( $self, %args ) = @_;


    my $sybase   = $self->{sybase};
    my $tws_date = $args{tws_date};

    my $query = 'select E.id, J.id, J.name, J.jobstream, J.command, E.mode, E.starttime, E.endtime, E.duration, E.exitcode, E.stdout, E.plan_date, E.tws_date, E.business_date, J.project, E.job_nr from tws_executions E, tws_jobs J where E.tws_job_id = J.id and E.tws_date = ?';
    my $result = $sybase->query( query => $query, values => [ $tws_date ], quiet => 1 );

    return unless $result;

    return $result;
}

#----------------------#
sub retrieve_tws_dates {
#----------------------#
    my ( $self, %args ) = @_;


    my $sybase   = $self->{sybase};

    my $query = 'select distinct(tws_date) from tws_executions order by tws_date desc';
    my $result = $sybase->query( query => $query, quiet => 1 );

    return unless $result;

    return map { $_->[0] } @{$result};
}

#-----------------#
sub cleanup_ctrlm {
#-----------------#
    my ( $self ) = @_;


    $self->{oracle}->do( statement => 'truncate table ctrlm_tables' );
    $self->{oracle}->do( statement => 'drop sequence ctrlm_tables_seq' );
    $self->{oracle}->do( statement => 'create sequence ctrlm_tables_seq start with 1' );
    $self->{oracle}->do( statement => 'truncate table ctrlm_jobs' );
    $self->{oracle}->do( statement => 'drop sequence ctrlm_jobs_seq' );
    $self->{oracle}->do( statement => 'create sequence ctrlm_jobs_seq start with 1' );
}

#----------------------#
sub record_ctrlm_table {
#----------------------#
    my ( $self, %args ) = @_;


    my $name              = $args{name};
    my $nr_jobs           = $args{nr_jobs};
    my $nr_in_conditions  = $args{nr_in_conditions};
    my $nr_out_conditions = $args{nr_out_conditions};
    my $nr_err_conditions = $args{nr_err_conditions};

    my $statement = 'insert into ctrlm_tables (id, name, nr_jobs, nr_in_conditions, nr_out_conditions, nr_err_conditions) values ( ctrlm_tables_seq.nextval, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $name, $nr_jobs, $nr_in_conditions, $nr_out_conditions, $nr_err_conditions ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#--------------------#
sub record_ctrlm_job {
#--------------------#
    my ( $self, %args ) = @_;


    my $tablename         = $args{table};
    my $name              = $args{name};
    my $job_type          = $args{job_type};
    my $task_type         = $args{task_type};
    my $ngroup            = $args{group};
    my $owner             = $args{owner};
    my $node_id           = $args{node_id};
    my $description       = $args{description};
    my $nr_in_conditions  = $args{nr_in_conditions};
    my $nr_out_conditions = $args{nr_out_conditions};
    my $nr_err_conditions = $args{nr_err_conditions};
    my $nr_resources      = $args{nr_resources};

    my $statement = 'insert into ctrlm_jobs (id, tablename, name, job_type, task_type, ngroup, owner, node_id, description, nr_in_conditions, nr_out_conditions, nr_err_conditions, nr_resources) values ( ctrlm_jobs_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $tablename, $name, $job_type, $task_type, $ngroup, $owner, $node_id, $description, $nr_in_conditions, $nr_out_conditions, $nr_err_conditions, $nr_resources ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#-----------------------#
sub retrieve_ctrlm_jobs {
#-----------------------#
    my ( $self ) = @_;


    my $query = 'select id, tablename, name, job_type, task_type, ngroup, owner, node_id, description, nr_in_conditions, nr_out_conditions, nr_err_conditions, nr_resources from ctrlm_jobs';

    my $result = $self->{oracle}->query( query => $query );

    return $result->all_rows;
}

#--------------------------#
sub record_md_upload_start {
#--------------------------#
    my ( $self, %args ) = @_;

    my $sybase       = $self->{sybase};
    my $channel      = $args{channel};
    my $status       = $args{status};
    my $xml_size     = $args{xml_size};
    my $win_user     = $args{win_user};
    my $md_group     = $args{md_group};
    my $action       = $args{action};
    my $md_date      = $args{md_date};
    my $mds          = $args{mds};
    my $script_id    = $args{script_id};
    my $pairs        = $args{pairs};

    my $timestamp    = time();

    my $statement = "insert into md_uploads (timestamp, channel, status, xml_size, win_user, md_group, action, md_date, mds, script_id) values ($timestamp, '$channel', '$status', $xml_size, '$win_user', '$md_group', '$action', '$md_date', '$mds', $script_id)";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    my $upload_id = $result->[0][0];

    $statement = 'insert into md_pairs (name, upload_id) values (?, ?)';
    foreach my $pair ( @{$pairs} ) {
        $sybase->do( statement => $statement, values => [ $pair, $upload_id ] );
    }

    return $upload_id;
}

#------------------#
sub record_job_run {
#------------------#
    my ( $self, %args ) = @_;


    my $id        = $args{id};
    my $starttime = $args{starttime};
    my $status    = $args{status};

    my $statement = 'update jobs set starttime = ?, status = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $starttime, $status, $id ] );
}

#---------------------#
sub update_job_status {
#---------------------#
    my ( $self, %args ) = @_;


    my $id     = $args{id};
    my $status = $args{status};

    my $statement = 'update jobs set status = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $status, $id ] );
}

#------------------#
sub record_job_end {
#------------------#
    my ( $self, %args ) = @_;


    my $id        = $args{id};
    my $endtime   = $args{endtime};
    my $duration  = $args{duration};
    my $exitcode  = $args{exitcode};
    my $status    = $args{status};

    my $statement = 'update jobs set endtime = ?, duration = ?, exitcode = ?, status = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $endtime, $duration, $exitcode, $status, $id ] );
}

#------------------------#
sub record_md_upload_end {
#------------------------#
    my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
    my $id              = $args{id};
    my $session_id      = $args{session_id};
    my $status          = $args{status};
    my $nr_not_imported = $args{nr_not_imported};
    my $xml_path        = $args{xml_path};

    my $statement = "update md_uploads set session_id = ?, status = ?, nr_not_imported = ?, xml_path = ? where id = ?";
    $sybase->do( statement => $statement, values => [ $session_id, $status, $nr_not_imported, $xml_path, $id ] );
}

#--------------------------#
sub record_statement_start {
#--------------------------#
    my ( $self, %args ) = @_;


    my $session_id      = $args{session_id} || 0;
    my $script_id       = $args{script_id}  || 0;
    my $service_id      = $args{service_id} || 0;
    my $schema          = $args{schema};
    my $username        = $args{username};
    my $sid             = $args{sid};
    my $hostname        = $args{hostname};
    my $osuser          = $args{osuser};
    my $pid             = $args{pid};
    my $program         = $args{program};
    my $command         = $args{command};
    my $starttime       = $args{starttime};
    my $duration        = $args{duration};
    my $cpu             = $args{cpu};
    my $wait_time       = $args{wait_time};
    my $logical_reads   = $args{logical_reads};
    my $physical_reads  = $args{physical_reads};
    my $physical_writes = $args{physical_writes};
    my $sql_text        = $args{sql_text};
    my $sql_tag         = $args{sql_tag};
    my $bind_values     = $args{bind_values};
#    my $business_date  = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} ) || '-';
    my $business_date   = Mx::Murex->calendardate() || '-';

    my $compressed_sql_text;
    gzip \$sql_text => \$compressed_sql_text;

    my $compressed_bind_values = freeze( $bind_values );

    my $statement = 'insert into statements (id, session_id, script_id, service_id, schema, username, sid, hostname, osuser, pid, program, command, starttime, duration, cpu, wait_time, logical_reads, physical_reads, physical_writes, sql_text, bind_values, sql_tag, business_date) values (statements_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?:B, ?:B, ?, ?) returning id into ?:O';

    my $values = [ $session_id, $script_id, $service_id, $schema, $username, $sid, $hostname, $osuser, $pid, $program, $command, $starttime, $duration, $cpu, $wait_time, $logical_reads, $physical_reads, $physical_writes, $sql_tag, $business_date ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, bl_values => [ $compressed_sql_text, $compressed_bind_values ], io_values => [ \$id ] );

    return $id;
}

#-------------------#
sub check_statement {
#-------------------#
    my ( $self, %args ) = @_;

    my $sybase    = $self->{sybase};
    my $spid      = $args{spid};
    my $starttime = $args{starttime};

    my $result = $sybase->query( query => "select id from statements where spid = ? and starttime = ?", values => [ $spid, $starttime ], quiet => 1 );

    return () unless $result;

    return $result->[0][0];
}

#------------------#
sub record_blocker {
#------------------#
    my ( $self, %args ) = @_;

    my $sybase         = $self->{sybase};
    my $statement_id   = $args{statement_id};
    my $spid           = $args{spid};
    my $db_name        = $args{db_name};
    my $pid            = $args{pid} || 0;
    my $login          = $args{login};
    my $hostname       = $args{hostname};
    my $application    = $args{application} || '';
    my $tran_name      = $args{tran_name} || '';
    my $cmd            = $args{cmd} || '';
    my $status         = $args{status};
    my $starttime      = $args{starttime};
    my $duration       = $args{duration};
    my $business_date  = Mx::Murex->calendardate() || '-';

    my $statement = "insert into blockers (statement_id, spid, db_name, pid, login, hostname, application, tran_name, cmd, status, starttime, duration, business_date) values ($statement_id, $spid, '$db_name', $pid, '$login', '$hostname', '$application', '$tran_name', '$cmd', '$status', $starttime, $duration, '$business_date')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity', quiet => 1 );
    return $result->[0][0];
}

#----------------------#
sub record_blocker_sql {
#----------------------#
    my ( $self, %args ) = @_;

    my $sybase         = $self->{sybase};
    my $id             = $args{id};
    my $sql_text       = $args{sql_text} || '';
    my $sql_tag        = $args{sql_tag} || '';

    my $compressed_sql_text;
    gzip \$sql_text => \$compressed_sql_text;

    my $statement = "update blockers set sql_text = ?, sql_tag = ? where id = ?";
    $sybase->do( statement => $statement, values => [ $compressed_sql_text, $sql_tag, $id ] );
}

#--------------------------#
sub session_has_statements {
#--------------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $result = $self->{oracle}->query( query => "select count(*) from statements where session_id = ?", values => [ $session_id ], quiet => 1 );

    return $result->nextref->[0];
}

#-------------------------#
sub script_has_statements {
#-------------------------#
    my ( $self, %args ) = @_;


    my $script_id = $args{script_id};

    my $result = $self->{oracle}->query( query => "select count(*) from statements where script_id = ?", values => [ $script_id ], quiet => 1 );

    return $result->nextref->[0];
}

#--------------------------#
sub service_has_statements {
#--------------------------#
    my ( $self, %args ) = @_;

    my $sybase     = $self->{sybase};
    my $service_id = $args{service_id};

    my $result = $sybase->query( query => "select count(*) from statements where service_id = ?", values => [ $service_id ], quiet => 1 );

    return () unless $result;

    return $result->[0][0];
}

#--------------------#
sub update_statement {
#--------------------#
    my ( $self, %args ) = @_;


    my $id              = $args{id};
    my $duration        = $args{duration};
    my $cpu             = $args{cpu};
    my $wait_time       = $args{wait_time};
    my $logical_reads   = $args{logical_reads};
    my $physical_reads  = $args{physical_reads};
    my $physical_writes = $args{physical_writes};

    my $statement = 'update statements set duration = ?, cpu = ?, wait_time = ?, logical_reads = ?, physical_reads = ?, physical_writes = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $duration, $cpu, $wait_time, $logical_reads, $physical_reads, $physical_writes, $id ] );
}

#------------------#
sub update_blocker {
#------------------#
    my ( $self, %args ) = @_;

    my $sybase   = $self->{sybase};
    my $id       = $args{id};
    my $duration = $args{duration};

    my $statement = "update blockers set duration = ? where id = ?";
    $sybase->do( statement => $statement, values => [ $duration, $id ] );
}

#------------------------#
sub record_statement_end {
#------------------------#
    my ( $self, %args ) = @_;


    my $id         = $args{id};
    my $endtime    = $args{endtime};
    my $duration   = $args{duration};
    my $plan_tag   = $args{plan_tag};

    my $statement = 'update statements set endtime = ?, duration = ?, plan_tag = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $endtime, $duration, $plan_tag, $id ] );
}

#--------------------------#
sub record_statement_waits {
#--------------------------#
    my ( $self, %args ) = @_;

    my $sybase       = $self->{sybase};
    my $statement_id = $args{statement_id};
    my $waits        = $args{waits};

    my $statement = "delete from statement_waits where statement_id = ?";
    $sybase->do( statement => $statement, values => [ $statement_id ], quiet => 1 );

    $statement = "insert into statement_waits ( statement_id, event_id, nr_waits, wait_time ) values ( $statement_id, ?, ?, ? )";
    $sybase->do_multiple( sql => $statement, values => $waits, quiet => 1 );
}

#----------------------------#
sub retrieve_statement_waits {
#----------------------------#
    my ( $self, %args ) = @_;

    my $sybase       = $self->{sybase};
    my $statement_id = $args{statement_id};

    my $query = "select A.event_id, B.description, A.nr_waits, A.wait_time from statement_waits A, wait_event_info B where A.statement_id = ? and A.event_id = B.event_id order by A.wait_time";

    my $result = $sybase->query( query => $query, values => [ $statement_id ], quiet => 1 );

    return $result;
}

#------------------------#
sub record_service_start {
#------------------------#
    my ( $self, %args ) = @_;


    my $name           = $args{name};
    my $starttime      = $args{starttime};
    my $duration       = $args{duration};
    my $rc             = $args{rc};
    my @processes      = @{$args{processes}};
#    my $business_date  = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date  = Mx::Murex->calendardate();

    my $statement = "insert into services (id, name, starttime, service_start_duration, service_start_rc, business_date) values (services_seq.nextval, ?, ?, ?, ?, ?) returning id into ?:O";

    my $values = [ $name, $starttime, $duration, $rc, $business_date ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    $statement = "insert into service_processes (service_id, label, hostname, pid, starttime) values (?, ?, ?, ?, ?)";
    foreach my $process ( @processes ) {
        if ( $process ) { 
            $self->{oracle}->do( statement => $statement, values => [ $id, $process->label, $process->hostname, $process->pid, $process->starttime ] );
        }
    }

    return $id;
}

#---------------------#
sub record_post_start {
#---------------------#
    my ( $self, %args ) = @_;


    my $service_id = $args{service_id};
    my $duration   = $args{duration};
    my $rc         = $args{rc};

    my $statement = "update services set post_start_duration = ?, post_start_rc = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ $duration, $rc, $service_id ] );
}

#-------------------#
sub record_pre_stop {
#-------------------#
    my ( $self, %args ) = @_;


    my $service_id = $args{service_id};
    my $duration   = $args{duration};
    my $rc         = $args{rc};

    my $statement = "update services set pre_stop_duration = ?, pre_stop_rc = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ $duration, $rc, $service_id ] );
}

#-----------------------#
sub record_service_stop {
#-----------------------#
    my ( $self, %args ) = @_;


    my $service_id     = $args{service_id};
    my $endtime        = $args{endtime};
    my $duration       = $args{duration};
    my $rc             = $args{rc};
    my @processes      = @{$args{processes}};

    my $statement = "update services set endtime = ?, service_stop_duration = ?, service_stop_rc = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ $endtime, $duration, $rc, $service_id ] );

    $statement = "update service_processes set endtime = ?, cpu_seconds = ?, vsize = ? where service_id = ? and label = ?";
    foreach my $process ( @processes ) {
        if ( $process ) {
            $self->{oracle}->do( statement => $statement, values => [ $endtime, $process->cputime, $process->vsz, $service_id, $process->label ] );
        }
    }
}

#----------------------------------#
sub retrieve_live_service_via_name {
#----------------------------------#
    my ( $self, %args ) = @_;


    my $name = $args{name};

    my $result = $self->{oracle}->query( query => "select id from services where name = ? and endtime is null order by id desc", values => [ $name ], quiet => 1 );

    return $result->nextref->[0];
}

#---------------------------------#
sub retrieve_live_service_via_pid {
#---------------------------------#
    my ( $self, %args ) = @_;


    my $pid      = $args{pid};
    my $hostname = $args{hostname};

    my $result = $self->{oracle}->query( query => "select service_id from service_processes where rtrim(hostname) = ? and pid = ? and endtime is null order by service_id desc", values => [ $hostname, $pid ], quiet => 0 );

    return $result->nextref->[0];
}

#---------------------------------#
sub retrieve_live_session_via_pid {
#---------------------------------#
    my ( $self, %args ) = @_;


    my $pid      = $args{pid};
    my $hostname = $args{hostname};

    my $result = $self->{oracle}->query( query => "select id from sessions where rtrim(hostname) = ? and pid = ? and exitcode is null", values => [ $hostname, $pid ], quiet => 0 );

    return $result->nextref->[0];
}

#--------------------------------#
sub retrieve_live_script_via_pid {
#--------------------------------#
    my ( $self, %args ) = @_;


    my $pid      = $args{pid};
    my $hostname = $args{hostname};

    my $result = $self->{oracle}->query( query => "select id from scripts where rtrim(hostname) = ? and pid = ? and exitcode is null", values => [ $hostname, $pid ], quiet => 0 );

    return $result->nextref->[0];
}

#---------------------#
sub record_task_start {
#---------------------#
    my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
    my $cmdline         = $args{cmdline};
    my $hostname        = $args{hostname};
    my $starttime       = time();
    my $name            = $args{name};
    my $logfile         = $args{logfile};
    my $xmlfile         = $args{xmlfile};
    my $sched_jobstream = $args{sched_jobstream} || 'NULL';
    my $statement = "insert into tasks (hostname, cmdline, starttime, name, logfile, xmlfile, sched_jobstream) values ('$hostname', '$cmdline', $starttime, '$name', '$logfile', '$xmlfile','$sched_jobstream')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#------------------#
sub record_message {
#------------------#
    my ( $self, %args ) = @_;


    my $type        = $args{type};
    my $priority    = $args{priority};
    my $environment = $args{environment};
    my $destination = $args{destination};
    my $timestamp   = $args{timestamp};
    my $validity    = $args{validity};
    my $message     = $args{message};

    my $statement = 'insert into messages (id, type, priority, environment, destination, timestamp, validity, message, processed) values (messages_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $type, $priority, $environment, $destination, $timestamp, $validity, $message, 0 ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#---------------------------------#
sub retrieve_unprocessed_messages {
#---------------------------------#
    my ( $self ) = @_;


    my $query = 'select id, type, priority, environment, destination, timestamp, validity, message from messages where processed = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ '0' ], quiet => 1 );

    return $result->all_rows();
}

#----------------------------#
sub update_processed_message {
#----------------------------#
    my ( $self, %args ) = @_;


    my $id = $args{id};

    my $statement = 'update messages set processed = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ '1', $id ] );
}

#---------------------------#
sub record_message_delivery {
#---------------------------#
    my ( $self, %args ) = @_;


    my $message_id = $args{message_id};
    my $username   = $args{username};
    my $delivered  = $args{delivered};
    my $timestamp  = $args{timestamp};

    my $statement = 'insert into message_delivery (id, message_id, username, delivered, delivery_ts) values (message_delivery_seq.nextval, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $message_id, $username, $delivered, $timestamp ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#-------------------------------#
sub record_message_confirmation {
#-------------------------------#
    my ( $self, %args ) = @_;


    my $delivery_id = $args{delivery_id};
    my $timestamp   = $args{timestamp};

    my $statement = 'update message_delivery set confirmation_ts = ? where id = ?';

    my $values = [ $timestamp, $delivery_id ];

    $self->{oracle}->do( statement => $statement, values => $values );
}

#-------------------------------#
sub retrieve_message_deliveries {
#-------------------------------#
    my ( $self, %args ) = @_;


    my $message_id = $args{message_id};

    my $query = 'select id, username, delivered, delivery_ts, confirmation_ts from message_delivery where message_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $message_id ] );

    return $result->all_rows();
}

#---------------#
sub record_core {
#---------------#
    my ( $self, %args ) = @_;


    my $session_id    = $args{session_id};
    my $pstack_path   = $args{pstack_path};
    my $pmap_path     = $args{pmap_path};
    my $core_path     = $args{core_path};
    my $hostname      = $args{hostname};
    my $size          = $args{size};
    my $timestamp     = $args{timestamp};
    my $win_user      = $args{win_user};
    my $mx_user       = $args{mx_user};
    my $mx_group      = $args{mx_group};
    my $mx_nick       = $args{mx_nick};
    my $function      = $args{function};
#    my $business_date = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date = Mx::Murex->calendardate();

    my $statement = 'insert into cores (id, session_id, pstack_path, pmap_path, core_path, hostname, size, timestamp, win_user, mx_user, mx_group, mx_nick, function, business_date) values (cores_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $session_id, $pstack_path, $pmap_path, $core_path, $hostname, $size, $timestamp, $win_user, $mx_user, $mx_group, $mx_nick, $function, $business_date ];

    my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#---------------------#
sub update_ab_session {
#---------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $id     = $args{id};
    my $pid    = $args{pid};
    my $statement = "update ab_sessions set pid = $pid, endtime = NULL where id = $id";
    $sybase->do( statement => $statement );
}

#------------------#
sub update_session {
#------------------#
    my ( $self, %args ) = @_;

    
    my $hostname  = $args{hostname};
    my $cmdline   = _compress_cmdline( $args{cmdline}, $self->{config} );
    $cmdline      = substr( $cmdline, 0, 3600 );

    my $statement = 'update sessions set hostname = ?, mx_starttime = ?, cmdline = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $hostname, time(), $cmdline, $args{session_id} ] );
}

#----------------------#
sub update_session_pid {
#----------------------#
    my ( $self, %args ) = @_;


    my $pid = $args{pid};

    my $statement = 'update sessions set pid = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $pid, $args{session_id} ] );
}

#-------------------------#
sub update_session_reruns {
#-------------------------#
    my ( $self, %args ) = @_;
    

    my $reruns = $args{reruns};

    my $statement = 'update sessions set reruns = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $reruns, $args{session_id} ] );
}

#-----------------------------#
sub update_session_nr_queries {
#-----------------------------#
    my ( $self, %args ) = @_;

    
    my $nr_queries = $args{nr_queries};

    my $statement = 'update sessions set nr_queries = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $nr_queries, $args{session_id} ] );
}

#-------------------#
sub cleanup_mxtable {
#-------------------#
    my ( $self ) = @_;


    $self->{oracle}->do( statement => 'truncate table mxtables' );
}

#------------------#
sub update_mxtable {
#------------------#
    my ( $self, %args ) = @_;
    

    my $name       = $args{name};
    my $schema     = $args{schema};
    my $nr_rows    = $args{nr_rows};
    my $data       = $args{data};
    my $indexes    = $args{indexes};
    my $lobs       = $args{lobs};
    my $lobindexes = $args{lobindexes};
    my $total_size = $args{total_size};

    my $statement = 'insert into mxtables ( name, schema, nr_rows, data, indexes, lobs, lobindexes, total_size ) values ( ?, ?, ?, ?, ?, ?, ?, ? )';

    $self->{oracle}->do( statement => $statement, values => [ $name, $schema, $nr_rows, $data, $indexes, $lobs, $lobindexes, $total_size ] );
}

#------------------------------#
sub update_mxtable_growth_rate {
#------------------------------#
    my ( $self, %args ) = @_;

    
    my $name         = $args{name};
    my $schema       = $args{schema};
    my $growth_rate  = $args{growth_rate};

    my $statement = 'update mxtables set growth_rate = ? where name = ? and schema = ?';

    $self->{oracle}->do( statement => $statement, values => [ $growth_rate, $name, $schema ] );
}
     
#---------------------#
sub historize_mxtable {
#---------------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $threshold = $args{threshold} || 0;
    my $force     = $args{force};
    my $timestamp = Mx::Util->epoch_to_iso();

    my $result = $self->{oracle}->query( query => 'select count(*) from mxtables_hist where timestamp = ?', values => [ $timestamp ] );

    if ( $result->nextref->[0] ) {
        $logger->warn("mxtables is already historized for timestamp $timestamp");

        if ( $force ) {
            $logger->error("force specified, cleaning up historized table");
            $self->{oracle}->do( statement => 'delete from mxtables_hist where timestamp = ?', values => [ $timestamp ] );
        }
        else {
            $logger->error("no force specified, aborting historize");
            return;
        }
    }

    $result = $self->{oracle}->query( query => 'select name, schema, nr_rows, total_size from mxtables where nr_rows > ?', values => [ $threshold ] );

    my $statement = 'insert into mxtables_hist ( timestamp, name, schema, nr_rows, total_size ) values ( ?, ?, ?, ?, ? )';

    while ( my ( $name, $schema, $nr_rows, $total_size ) = $result->next ) {
        $self->{oracle}->do( statement => $statement, values => [ $timestamp, $name, $schema, $nr_rows, $total_size ] );
    }

    return 1;
}

#----------------#
sub top_mxtables {
#----------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $count     = $args{count} || 10;
    my $criterium = $args{criterium} || 'total_size';
    my $schema    = $args{schema};

    unless ( $criterium eq 'total_size' or $criterium eq 'nr_rows' ) {
        $logger->warn("unknown criterium ($criterium), selecting 'total_size'");
        $criterium = 'reserved';
    }

    my $query     = 'select max(timestamp) from mxtables_hist where schema = ?';
    my $result    = $self->{oracle}->query( query => $query, values => [ $schema ] );
    my $timestamp = $result->nextref->[0];

    $query  = "select top $count name from mxtables_hist where schema = ? and timestamp = ? order by $criterium desc";
    $result = $self->{oracle}->query( query => $query, values => [ $schema, $timestamp ] );

    return map { $_->[0] } $result->all_rows;
}

#------------------#
sub total_mxtables {
#------------------#
    my ( $self, %args ) = @_;


    my $schema = $args{schema};

    my $query = 'select timestamp, ceiling(sum(total_size / 1.0)) from mxtables_hist where schema = ? group by timestamp order by timestamp';

    my $result = $self->{oracle}->query( query => $query, values => [ $schema ] );

    return $result->all_rows;
}

#-----------------#
sub mxtable_sizes {
#-----------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $name      = $args{name};
    my $criterium = $args{criterium} || 'total_size';
    my $schema    = $args{schema};

    unless ( $criterium eq 'total_size' or $criterium eq 'nr_rows' or $criterium =~ /^nr_rows\s*,\s*total_size$/ ) {
        $logger->warn("unknown criterium ($criterium), selecting 'total_size'");
        $criterium = 'total_size';
    }

    my $query = "select timestamp, $criterium from mxtables_hist where name = ? and schema = ? order by timestamp";

    my $result = $self->{oracle}->query( query => $query, values => [ $name, $schema ] );

    return $result->all_rows;
}

#---------------------------#
sub mxtable_timestamp_range {
#---------------------------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $name      = $args{name};
    my $schema    = $args{schema};

    my $query = 'select min(timestamp), max(timestamp) from mxtables_hist where name = ? and schema = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $name, $schema ] );

    return $result->next;
}

#----------------------#
sub cleanup_mxml_nodes {
#----------------------#
    my ( $self ) = @_;


    $self->{oracle}->do( statement => 'truncate table mxml_nodes' );
    $self->{oracle}->do( statement => 'truncate table mxml_tasks' );
    $self->{oracle}->do( statement => 'truncate table mxml_links' );
    $self->{oracle}->do( statement => 'truncate table mxml_directories' );
}

#--------------------#
sub insert_mxml_node {
#--------------------#
    my ( $self, %args ) = @_;
    

    my $id          = $args{id};
    my $nodename    = $args{nodename};
    my $in_out      = $args{in_out};
    my $taskname    = $args{taskname};
    my $tasktype    = $args{tasktype};
    my $sheetname   = $args{sheetname};
    my $workflow    = $args{workflow};
    my $target_task = $args{target_task};
    my $statement = 'insert into mxml_nodes ( id, nodename, in_out, taskname, tasktype, sheetname, workflow, target_task ) values ( ?, ?, ?, ?, ?, ?, ?, ? )'; 
    $self->{oracle}->do( statement => $statement, values => [ $id, $nodename, $in_out, $taskname, $tasktype, $sheetname, $workflow, $target_task ] );
}

#--------------------#
sub insert_mxml_task {
#--------------------#
    my ( $self, %args ) = @_;
   

    my $taskname   = $args{taskname};
    my $tasktype   = $args{tasktype};
    my $sheetname  = $args{sheetname};
    my $workflow   = $args{workflow};
    my $status     = $args{status};
    my $timestamp  = time();
    my $statement = 'insert into mxml_tasks ( taskname, tasktype, sheetname, workflow, status, timestamp ) values ( ?, ?, ?, ?, ?, ? )'; 
    $self->{oracle}->do( statement => $statement, values => [ $taskname, $tasktype, $sheetname, $workflow, $status, $timestamp ] );
}

#--------------------#
sub insert_mxml_link {
#--------------------#
    my ( $self, %args ) = @_;
    
    my $id          = $args{id};
    my $target_task = $args{target_task};
    my $statement = 'insert into mxml_links ( id, target_task ) values ( ?, ? )';
    $self->{oracle}->do( statement => $statement, values => [ $id, $target_task ] );
}

#---------------------------#
sub insert_mxml_directories {
#---------------------------#
    my ( $self, %args ) = @_;
    
    my $taskname    = $args{taskname};
    my $received    = $args{received};
    my $error       = $args{error};
    my $statement = 'insert into mxml_directories ( taskname, received, error ) values ( ?, ?, ? )';
    $self->{oracle}->do( statement => $statement, values => [ $taskname, $received, $error ] );
}

#--------------------#
sub update_mxml_node {
#--------------------#
    my ( $self, %args ) = @_;
    

    my $id          = $args{id};
    my $msg_taken_n = $args{msg_taken_n};

    if ( exists $args{msg_taken_y} ) {
        my $msg_taken_y = $args{msg_taken_y};
        if ( my $proc_time = $args{proc_time} ) {
            my $statement = 'update mxml_nodes set msg_taken_y = ?, msg_taken_n = ?, proc_time = ? where id = ?';
            $self->{oracle}->do( statement => $statement, values => [ $msg_taken_y, $msg_taken_n, $proc_time, $id ] );
        }
        else {
            my $statement = "update mxml_nodes set msg_taken_y = ?, msg_taken_n = ? where id = '$id'";
            $self->{oracle}->do( statement => $statement, values => [ $msg_taken_y, $msg_taken_n ] );
        }
    }
    else {
        if ( my $proc_time = $args{proc_time} ) {
            my $statement = 'update mxml_nodes set msg_taken_n = ?, proc_time = ? where id = ?';
            $self->{oracle}->do( statement => $statement, values => [ $msg_taken_n, $proc_time, $id ] );
        }
        else {
            my $statement = 'update mxml_nodes set msg_taken_n = ? where id = ?';
            $self->{oracle}->do( statement => $statement, values => [ $msg_taken_n, $id ] );
        }
    }
}

#--------------------#
sub update_mxml_task {
#--------------------#
    my ( $self, %args ) = @_;
    

    my $taskname     = $args{taskname};
    my $unblocked    = $args{unblocked};
    my $loading_data = $args{loading_data};
    my $started      = $args{started};
    my $status       = $args{status};
    my $timestamp    = $args{timestamp};

    if ( $status ) {
        my $statement = 'update mxml_tasks set status = ?, timestamp = ? where taskname = ?';
        $self>{oracle}->do( statement => $statement, values => [ $status, $timestamp, $taskname ] );
    }
    else {
        my $statement = 'update mxml_tasks set unblocked = ?, loading_data = ?, started = ?, timestamp = ? where taskname = ?';
        $self->{oracle}->do( statement => $statement, values => [ $unblocked, $loading_data, $started, $timestamp, $taskname ] );
    }
}

#-------------------------#
sub update_mxml_node_hist {
#-------------------------#
    my ( $self, %args ) = @_;

    
    my $id          = $args{id};
    my $timestamp   = $args{timestamp};
    my $msg_taken_n = $args{msg_taken_n};

    my $statement = 'insert into mxml_nodes_hist ( id, timestamp, msg_taken_n ) values ( ?, ?, ? )';
    $self->{oracle}->do( statement => $statement, values => [ $id, $timestamp, $msg_taken_n ] );
}

#-----------------------------#
sub mxml_node_timestamp_range {
#-----------------------------#
    my ( $self, %args ) = @_;


    my $query  = 'select min(timestamp), max(timestamp) from mxml_nodes_hist';
    my $result = $self->{oracle}->query( query => $query );

    return $result->next;
}

#-----------------#
sub update_report {
#-----------------#
    my ( $self, %args ) = @_;
    
    my $sybase = $self->{sybase};
    if ( my $tablename = $args{tablename} ) {
        my $statement = 'update reports set tablename = ? where id = ?';
        $sybase->do( statement => $statement, values => [ $tablename, $args{id} ] );
    }
    elsif ( my $path = $args{path} ) {
        my $statement = 'update reports set path = ? where id = ?';
        $sybase->do( statement => $statement, values => [ $path, $args{id} ] );
    }
}

#-------------------------#
sub record_session_mx_end {
#-------------------------#
    my ( $self, %args ) = @_;


    my $statement = 'update sessions set mx_endtime = ?, exitcode = ?, pid = ?, corefile = ?, mx_user = ?, mx_group = ?, cpu_seconds = ?, vsize = ? where id = ?';
    $self->{oracle}->do( statement => $statement, values => [ time(), $args{exitcode}, $args{pid}, $args{corefile}, $args{mx_user}, $args{mx_group}, $args{cpu_seconds}, $args{vsize}, $args{session_id} ] );
}

#--------------------------#
sub record_session_req_end {
#--------------------------#
    my ( $self, %args ) = @_;


    my $statement = 'update sessions set req_endtime = ?, exitcode = ?, runtime = ?, cputime = ?, iotime = ?, start_delay = ? where id = ?';
    $self->{oracle}->do( statement => $statement, values => [ time(), $args{exitcode}, $args{runtime}, $args{cputime}, $args{iotime}, $args{start_delay}, $args{session_id} ] );
}

#----------------------#
sub record_scanner_end {
#----------------------#
    my ( $self, %args ) = @_;


    my $statement = 'update sessions set runtime = ?, cputime = ?, iotime = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $args{runtime}, $args{cputime}, $args{iotime}, $args{session_id} ] );
}

#---------------------#
sub record_script_end {
#---------------------#
    my ( $self, %args ) = @_;

    my $statement = 'update scripts set endtime = ?, exitcode = ?, cpu_seconds = ?, vsize = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ time(), $args{exitcode}, $args{cpu_seconds}, $args{vsize}, $args{id} ] );
}

#-----------------------#
sub record_transfer_end {
#-----------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $statement = 'update transfers set endtime = ?, exitcode = ?, cdpid = ?, reruns = ? where id = ?';
    $sybase->do( statement => $statement, values => [ time(), $args{exitcode}, $args{cdpid}, $args{reruns}, $args{id} ] );
}

#------------------------#
sub set_session_exitcode {
#------------------------#
    my ( $self, %args ) = @_;


    my $statement = 'update sessions set exitcode = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $args{exitcode}, $args{session_id} ] );
}

#-----------------#
sub mark_for_kill {
#-----------------#
    my ( $self, %args ) = @_;


    my $statement = 'update sessions set killed = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ '1', $args{session_id} ] );
}

#--------------------------#
sub mark_transfer_for_kill {
#--------------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $statement = 'update transfers set killed = ? where id = ?';
    $sybase->do( statement => $statement, values => [ '1', $args{id} ] );
}

#----------------------#
sub record_runtime_end {
#----------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $statement = "update runtimes set endtime = ?, exitcode = ? where id = ?";
    $sybase->do( statement => $statement, values => [ time(), $args{exitcode}, $args{id} ] );
}

#-------------------#
sub record_task_end {
#-------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $statement = 'update tasks set endtime = ?, pid = ?, exitcode = ? where id = ?';
    $sybase->do( statement => $statement, values => [ time(), $args{pid}, $args{exitcode}, $args{task_id} ] );
}

#
# Arguments
#
# session_id
#
#----------------#
sub get_exitcode {
#----------------#
    my ( $self, %args ) = @_;


    my $query = 'select exitcode, req_starttime, mx_starttime from sessions where id = ?';

    my $count = 0;
    while ( my $result = $self->{oracle}->query( query => $query, values => [ $args{session_id} ] ) ) {
        if ( my @rows = $result->all_rows ) {
            return $rows[0];
        }
        else {
            sleep 1;
            return if ++$count == 10;
        }
    }
}

#-----------#
sub get_pid {
#-----------#
    my ( $self, %args ) = @_;


    my $query = 'select pid from sessions where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $args{session_id} ] );

    return $result->nextref->[0];
}

#-------------------#
sub get_start_delay {
#-------------------#
    my ( $self, %args ) = @_;


    my $query = 'select start_delay from sessions where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $args{session_id} ] );

    return $result->nextref->[0];
}

#-----------------------#
sub get_max_start_delay {
#-----------------------#
    my ( $self, %args ) = @_;


    my $interval = $args{interval} || 600;

    my $starttime = time() - $interval;

    my $query = 'select max(start_delay) from sessions where mx_starttime > ? and start_delay <= 600';

    my $result = $self->{oracle}->query( query => $query, values => [ $starttime ] );

    return $result->nextref->[0];
}

#-------------------------#
sub retrieve_start_delays {
#-------------------------#
    my ( $self, %args ) = @_;


    my $date  = $args{date};
    my @types = ( $args{types} ) ? @{$args{types}} : ();

    my $query = 'select mx_starttime, start_delay from sessions where business_date = ? and start_delay > 0';

    if ( @types ) {
        map { $_ = "'$_\'" } @types;
        my $typelist = join ',', @types;
        $query .= " and mx_scripttype in ($typelist)";
    }

    $query .= ' order by mx_starttime asc';

    my $result = $self->{oracle}->query( query => $query, values => [ $date ] );

    return $result->all_rows;
}

#--------------------------#
sub retrieve_remote_delays {
#--------------------------#
    my ( $self, %args ) = @_;


    my $date  = $args{date};
    my @types = ( $args{types} ) ? @{$args{types}} : ();

    my $query = 'select req_starttime, remote_delay from sessions where business_date = ? and remote_delay is not null';

    if ( @types ) {
        map { $_ = "'$_'" } @types;
        my $typelist = join ',', @types;
        $query .= " and mx_scripttype in ($typelist)";
    }

    $query .= ' order by req_starttime asc';

    my $result = $self->{oracle}->query( query => $query, values => [ $date ] );

    return $result->all_rows;
}

#
# Arguments
#
# session_id
# nr_books_ok
# nr_books_nok
#
#-------------------------#
sub record_ab_session_end {
#-------------------------#
    my ( $self, %args ) = @_;

    my $sybase = $self->{sybase};
    my $statement = 'update ab_sessions set endtime = ?, nr_books_ok = ?, nr_books_nok = ? where id = ?';
    $sybase->do( statement => $statement, values => [ time(), $args{nr_books_ok}, $args{nr_books_nok}, $args{session_id} ] );
}

#---------------------#
sub retrieve_sessions {
#---------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_sessions';
    return $self->_retrieve( %args );
}

#----------------------#
sub retrieve_sessions2 {
#----------------------#
    my ( $self, %args ) = @_;
 
 
    my @sessions  = ();

    my $starttime = $args{starttime};
    my $endtime   = $args{endtime};
    my @types     = ( $args{types} )    ? @{$args{types}}    : ();
    my @projects  = ( $args{projects} ) ? @{$args{projects}} : ();
 
    my $query = 'select id, hostname, req_starttime, mx_starttime, mx_endtime, req_endtime, mx_scripttype, mx_scriptname, win_user, mx_nick, entity, exitcode, remote_delay, duration from sessions where ( mx_starttime > ? or req_starttime > ? ) and ( mx_starttime < ? or req_starttime < ? )';

    if ( @types ) {
        map { $_ = "'$_'" } @types;
        my $typelist = join ',', @types;
        $query .= " and mx_scripttype in ($typelist)";
        
    }

    if ( @projects ) {
        map { $_ = "'$_'" } @projects;
        my $projectlist = join ',', @projects;
        $query .= " and project in ($projectlist)";
        
    }

    $query .= ' order by id';

    my $result = $self->{oracle}->query( query => $query, values => [ $starttime, $starttime, $endtime, $endtime ] );

    while( my $row = $result->nextref ) {
        last unless @{$row};

        my %session = ();

        $session{id}           = $row->[0];
        $session{hostname}     = $row->[1];
        my $req_starttime      = $row->[2];
        my $mx_starttime       = $row->[3];
        $session{starttime}    = ( $req_starttime ) ? $req_starttime : $mx_starttime;
        my $mx_endtime         = $row->[4];
        my $req_endtime        = $row->[5];
        $session{endtime}      = ( $req_endtime ) ? $req_endtime : $mx_endtime;
        $session{type}         = $row->[6];
        $session{name}         = $row->[7];
        $session{user}         = $row->[8];
        $session{nick}         = $row->[9];
        $session{entity}       = $row->[10];
        $session{exitcode}     = $row->[11];
        $session{remote_delay} = $row->[12];
        $session{duration}     = $row->[13];

        push @sessions, { %session };
    }

    return @sessions;
}

#----------------------#
sub retrieve_sessions3 {
#----------------------#
    my ( $self, %args ) = @_;
 
 
    my @sessions  = ();

    my $business_date = $args{business_date};
    my $mxtiming      = $args{mxtiming};
    my $mxtiming_max  = $args{mxtiming_max};
    my $sqlio         = $args{sqlio};
    my $memory        = $args{memory};
    my @scripttypes   = ( $args{scripttypes} ) ? @{$args{scripttypes}} : ();
    my @runtypes      = ( $args{runtypes} )    ? @{$args{runtypes}}    : ();
    my @projects      = ( $args{projects} )    ? @{$args{projects}}    : ();
 
    my $query = 'select id, mx_starttime, mx_endtime, mx_scriptname, entity, exitcode, cpu_seconds, vsize from sessions where business_date = ?';

    if ( @scripttypes ) {
        map { $_ = "'$_'" } @scripttypes;
        my $typelist = join ',', @scripttypes;
        $query .= " and mx_scripttype in ($typelist)";
        
    }

    if ( @runtypes ) {
        map { $_ = "'$_'" } @runtypes;
        my $typelist = join ',', @runtypes;
        $query .= " and runtype in ($typelist)";
        
    }

    if ( @projects ) {
        map { $_ = "'$_'" } @projects;
        my $projectlist = join ',', @projects;
        $query .= " and project in ($projectlist)";
        
    }

    $query .= ' order by exitcode';

    my $result = $self->{oracle}->query( query => $query, values => [ $business_date ] );

    while ( my $row = $result->nextref ) {
        last unless @{$row};

        my %session = ();

        $session{id}          = $row->[0];
        $session{starttime}   = $row->[1];
        $session{endtime}     = $row->[2];
        $session{scriptname}  = $row->[3];
        $session{entity}      = $row->[4];
        $session{exitcode}    = $row->[5];
        $session{cpu_seconds} = $row->[6];
        $session{vsize}       = $row->[7];

        if ( $mxtiming ) {
            my $query  = 'select elapsed, cpu, rdb from timings where session_id = ? and context = ?';
            if ( my $result = $self->{oracle}->query( query => $query, values => [ $session{id}, 'Totals' ] ) ) {
                my $row = $result->nextref;
                $session{elapsed} = $row->[0];
                $session{cpu}     = $row->[1];
                $session{rdb}     = $row->[2];
            }
        }

        if ( $mxtiming_max ) {
            my $query  = 'select elapsed, cpu, rdb from timings where session_id = ? and context <> ? order by elapsed desc';
            if ( my $result = $self->{oracle}->query( query => $query, values => [ $session{id}, 'Totals' ] ) ) {
                my $row = $result->nextref;
                $session{elapsed_max} = $row->[0];
                $session{cpu_max}     = $row->[1];
                $session{rdb_max}     = $row->[2];
            }
        }

        if ( $sqlio ) {
            my $query = 'select logical, physical from sqlio where session_id = ? and name = ?';
            if ( my $result = $self->{oracle}->query( query => $query, values => [ $session{id}, 'TOTAL' ] ) ) {
                my $row = $result->nextref;
                $session{logical}  = $row->[0];
                $session{physical} = $row->[1];
            }
            
        }

        if ( $memory ) {
            my $query = 'select vsize, rss, anon from memory where session_id = ? order by timestamp desc';
            if ( my $result = $self->{oracle}->query( query => $query, values => [ $session{id} ] ) ) {
                my $row = $result->nextref;
                $session{vsize} = $row->[0];
                $session{rss}   = $row->[1];
                $session{anon}  = $row->[2];
            }
            
        }

        push @sessions, { %session };
    }

    return @sessions;
}

#----------------------#
sub retrieve_sessions4 {
#----------------------#
    my ( $self, %args ) = @_;
    my @sessions  = ();
   
    my $sched_jobstream = $args{sched_jobstream};
    my $business_date 	=  $args{business_date};
    my $query  = "select exitcode from sessions where business_date = '$business_date' and sched_jobstream like '%$sched_jobstream' order by req_starttime";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    foreach my $row ( @{$result} ) {
        my %session = ();
        $session{exitcode}  = $row->[0];
        push @sessions, { %session };
    }

    return @sessions;
}

#----------------------#
sub retrieve_sessions5 {
#----------------------#
    my ( $self, %args ) = @_;
    my @sessions  = ();
   
    my $sched_jobstream = $args{sched_jobstream};
    my $business_date 	=  $args{business_date};
    my $script_name 	=  $args{script_name};		
    my $query  = "select exitcode from sessions where business_date = '$business_date' and sched_jobstream like '%$sched_jobstream' and mx_scriptname = '$script_name' order by req_starttime";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    foreach my $row ( @{$result} ) {
        my %session = ();
        $session{exitcode}  = $row->[0];
        push @sessions, { %session };
    }

    return @sessions;
}

#----------------------#
sub retrieve_sessions6 {
#----------------------#
    my ( $self, %args ) = @_;
    my @sessions  = ();
   
    my $sched_jobstream = $args{sched_jobstream};
    my $business_date 	=  $args{business_date};
    my $script_name 	=  $args{script_name};		
    my $query  = "select sched_jobstream, mx_scriptname, exitcode from sessions where business_date = '$business_date' and sched_jobstream like '%WMX%' order by sched_jobstream, mx_scriptname, req_starttime";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    foreach my $row ( @{$result} ) {
        my %session = ();
        $session{sched_jobstream} = $row->[0];
	$session{mx_scriptname} = $row->[1];
        $session{exitcode} = $row->[2];
        push @sessions, { %session };
    }

    return @sessions;
}

#----------------------#
sub retrieve_sessions7 {
#----------------------#
    my ( $self, %args ) = @_;


    my $sybase    = $self->{sybase};
    my $starttime = $args{starttime};
    my $endtime   = $args{endtime};

    my $query = "select win_user, mx_group, mx_starttime, mx_endtime, pid, cpu_seconds, duration from sessions where win_user != '' and duration != 0 and mx_starttime > ? and mx_starttime < ?";

    my $result = $sybase->query( query => $query, values => [ $starttime, $endtime ] );

    return () unless $result;

    return @{$result};
}

#----------------------#
sub retrieve_sessions8 {
#----------------------#
    my ( $self, %args ) = @_;

 
    my @scripttypes = @{$args{scripttypes}};
    my @runtypes    = @{$args{runtypes}};

    map { $_ = "'$_'" } @scripttypes;
    map { $_ = "'$_'" } @runtypes;

    my $scriptlist = join ',', @scripttypes;
    my $runlist    = join ',', @runtypes;

    my $query = "select mx_scriptname, mx_scripttype, runtype, entity from sessions where mx_scripttype in ($scriptlist) and runtype in ($runlist) group by mx_scriptname, mx_scripttype, runtype, entity";

    my $result = $self->{oracle}->query( query => $query );

    return $result->all_rows();
}

#----------------------#
sub retrieve_sessions9 {
#----------------------#
    my ( $self, %args ) = @_;

 
    my $scriptname  = $args{scriptname};
    my $scripttype  = $args{scripttype};
    my $runtype     = $args{runtype};
    my $entity      = $args{entity};
 
    my $query = "select id, mx_starttime, mx_endtime, exitcode, cpu_seconds, vsize, business_date from sessions where mx_scriptname = ? and mx_scripttype = ? and runtype = ? and entity = ? ";

    my $result = $self->{oracle}->query( query => $query, values => [ $scriptname, $scripttype, $runtype, $entity ], quiet => 1 );

    return $result->all_rows();
}

#--------------------#
sub retrieve_scripts {
#--------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_scripts';
    return $self->_retrieve( %args );
}

#------------------------#
sub retrieve_webcommands {
#------------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_webcommands';
    return $self->_retrieve( %args );
}

#----------------------#
sub retrieve_transfers {
#----------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_transfers';
    return $self->_retrieve( %args );
}

#---------------------#
sub retrieve_runtimes {
#---------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_runtimes';
    return $self->_retrieve( %args );
}

#-----------------#
sub retrieve_jobs {
#-----------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_jobs';
    return $self->_retrieve( %args );
}

#------------------#
sub retrieve_tasks {
#------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_tasks';
    return $self->_retrieve( %args );
}

#---------------------#
sub retrieve_messages {
#---------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_messages';
    return $self->_retrieve( %args );
}

#-----------------------#
sub retrieve_statements {
#-----------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_statements';
    return $self->_retrieve( %args );
}

#------------------------#
sub statement_statistics {
#------------------------#
    my ( $self, %args ) = @_;
   

    my $query = 'select business_date, count(*), sum(duration), sum(wait_time/1000), sum(cpu/1000), sum(physical_reads/1000), sum(logical_reads/1000) from statements group by business_date order by business_date';

    my $result = $self->{oracle}->query( query => $query );

    return $result->all_rows;
}

#-------------------#
sub lock_statistics {
#-------------------#
    my ( $self, %args ) = @_;
   

    my $query = 'select business_date, count(*), sum(duration) from blockers group by business_date order by business_date';

    my $result = $self->{oracle}->query( query => $query );

    return $result->all_rows;
}

#---------------------#
sub retrieve_blockers {
#---------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_blockers';

    return $self->_retrieve( %args );
}

#------------------------#
sub retrieve_nr_blockers {
#------------------------#
    my ( $self, %args ) = @_;
   

    my $statement_id = $args{statement_id};

    my $query = 'select count(*) from blockers where statement_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $statement_id ] );

    return $result->nextref->[0];
}

#------------------#
sub retrieve_cores {
#------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_cores';

    return $self->_retrieve( %args );
}

#---------------------#
sub retrieve_services {
#---------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_services';

    return $self->_retrieve( %args );
}

#-----------------------#
sub retrieve_md_uploads {
#-----------------------#
    my ( $self, %args ) = @_;
   
    my $query = "select id, timestamp, type, channel, status, nr_not_imported, xml_path, xml_size, win_user, md_group, action, md_date, mds, script_id, session_id from md_uploads";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );

    return $result;
}

#----------------------#
sub retrieve_md_upload {
#----------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query = "select id, timestamp, type, channel, status, nr_not_imported, xml_path, xml_size, win_user, md_group, action, md_date, mds, script_id, session_id from md_uploads where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    my $row = $result->[0];

    $query = "select name from md_pairs where upload_id = $id";
    $result = $sybase->query( query => $query );
    my @pairs = map { $_->[0] } @{$result};

    push @{$row}, [ @pairs ];

    return $row;
}

#--------------------#
sub retrieve_session {
#--------------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};

    my $query  = 'select id, rtrim(hostname), cmdline, req_starttime, mx_starttime, mx_endtime, req_endtime, mx_scripttype, mx_scriptname, rtrim(win_user), mx_user, mx_group, rtrim(mx_client_host), exitcode, ab_session_id, runtime, cputime, iotime, pid, corefile, sched_jobstream, entity, runtype, rtrim(business_date), duration, mx_nick, project, reruns, killed, start_delay, cpu_seconds, vsize, remote_delay, nr_queries from sessions where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    my $row = $result->nextref;

    $row->[2] = _decompress_cmdline( $row->[2], $self->{config} );

    return $row;
}

#---------------------#
sub retrieve_session2 {
#---------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = "select mx_scripttype, mx_scriptname, entity, runtype from sessions where id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $id ], quiet => 1 );

    return $result->nextref;
}

#-------------------#
sub retrieve_script {
#-------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = 'select id, scriptname, path, cmdline, rtrim(hostname), pid, username, starttime, endtime, exitcode, project, sched_jobstream, rtrim(business_date), duration, killed, cpu_seconds, vsize, logfile, name from scripts where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#---------------------#
sub retrieve_transfer {
#---------------------#
    my ( $self, %args ) = @_;

    my $id = $args{id};
    my $query  = "select id, rtrim(hostname), project, sched_jobstream, entity, content, target, starttime, endtime, duration, filelength, reruns, killed, exitcode, cmdline, pid, cdpid, username, rtrim(business_date), logfile, cdkeyfile from transfers where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return $result->[0];
}

#-----------------#
sub retrieve_task {
#-----------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select id, rtrim(hostname), cmdline, starttime, endtime, name, exitcode, logfile, xmlfile, sched_jobstream, pid, rtrim(business_date), duration from tasks where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return $result->[0];
}

#--------------------#
sub retrieve_reports {
#--------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_reports';
    return $self->_retrieve( %args );
}

#-------------------#
sub retrieve_report {
#-------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = 'select id, label, type, session_id, batchname, reportname, entity, runtype, mds, starttime, endtime, size, nr_records, tablename, path, rtrim(business_date), duration, ab_session_id, command, exitcode, cduration, status, compressed, archived, filter from reports where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#-----------------------#
sub retrieve_dm_reports {
#-----------------------#
    my ( $self, %args ) = @_;


    $args{stored_procedure} = 'sp_page_dm_reports';
    return $self->_retrieve( %args );
}

#----------------------#
sub retrieve_dm_report {
#----------------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};

    my $query = 'select id, label, type, script_id, name, directory, rmode, starttime, endtime, rsize, nr_records, project, entity, runtype, business_date from dm_reports where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#-------------------------#
sub retrieve_feedertables {
#-------------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_feedertables';
    return $self->_retrieve( %args );
}

#------------------------#
sub retrieve_feedertable {
#------------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = 'select id, session_id, name, batch_name, feeder_name, entity, runtype, timestamp, job_id, ref_data, nr_records, tabletype from feedertables where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#----------------------#
sub retrieve_dm_filter {
#----------------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};

    my $query = 'select id, session_id, batch_name, dates, mds, products, portfolios, expression from dm_filters where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#----------------------#
sub retrieve_statement {
#----------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = 'select id, session_id, script_id, service_id, schema, username, sid, hostname, osuser, pid, program, command, starttime, endtime, duration, cpu, wait_time, logical_reads, physical_reads, physical_writes, sql_text, bind_values, sql_tag, plan_tag, business_date from statements where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

	my $row = $result->nextref;

    my $compressed_sql_text = $row->[20];
    my $sql_text;
    gunzip \$compressed_sql_text => \$sql_text;
    $row->[20] = $sql_text;

    my $bind_values = thaw( $row->[21] );
    $row->[21] = $bind_values;

    return $row;
}

#--------------------#
sub retrieve_blocker {
#--------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query = "select id, statement_id, spid, db_name, pid, login, hostname, application, tran_name, cmd, status, starttime, duration, sql_text, sql_tag, business_date from blockers where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );

    my $compressed_sql_text = $result->[0][13];
    my $sql_text;
    gunzip \$compressed_sql_text => \$sql_text;
    $result->[0][13] = $sql_text;

    return $result->[0];
}

#---------------------#
sub retrieve_sql_tags {
#---------------------#
    my ( $self ) = @_;

 
    my $sybase = $self->{sybase};

    my $query = 'select count(*) as cnt, sql_tag from statements group by sql_tag having count(*) > 10 order by cnt desc';
    my $result = $sybase->query( query => $query );

    return @{$result};
}

#-------------------#
sub retrieve_alerts {
#-------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_alerts';
    return $self->_retrieve( %args );
}

#-----------------------------#
sub retrieve_logfile_extracts {
#-----------------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_logfiles';
    return $self->_retrieve( %args );
}

#---------------------#
sub retrieve_mxtables {
#---------------------#
    my ( $self, %args ) = @_;


    my $schema = $args{schema};

    my $query  = "select A.name, A.schema, A.nr_rows, A.data, A.indexes, A.lobs, A.lobindexes, A.total_size, A.growth_rate, B.category from mxtables A left outer join mxtables_category B on A.schema = B.schema and A.name = B.name where A.schema = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $schema ] );

    return unless $result;

    return $result->all_rows;
}

#--------------------#
sub retrieve_mxtable {
#--------------------#
    my ( $self, %args ) = @_;


    my $schema = $args{schema};
    my $name   = $args{name};

    my $query  = "select A.name, A.schema, A.nr_rows, A.data, A.indexes, A.lobs, A.lobindexes, A.total_size, A.growth_rate, B.category from mxtables A left outer join mxtables_category B on A.schema = B.schema and A.name = B.name where A.schema = ? and A.name = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $schema, $name ] );

    return unless $result;

    return $result->all_rows;
}

#---------------------#
sub retrieve_statements_stats {
#---------------------#
    my ( $self, %args ) = @_;


    my $sybase  = $self->{sybase};
		my $config      = $self->{config};
    my $stddev_factor = $config->retrieve('STDDEV_FACTOR');
    my $cpu_time_threshold = $config->retrieve('SYB_THRESHOLD_CPU_TIME');
    my $wait_time_threshold = $config->retrieve('SYB_THRESHOLD_WAIT_TIME');
    my $preads_threshold = $config->retrieve('SYB_THRESHOLD_PHYSICAL_READS');
    my $lreads_threshold = $config->retrieve('SYB_THRESHOLD_LOGICAL_READS');


    my $query  = "select statements.id, statements.business_date,statements.sql_tag,statements.wait_time, statements_stats.avg_wait_time, statements_stats.stddev_wait_time,statements.cpu_time, statements_stats.avg_cpu_time, statements_stats.stddev_cpu_time,
statements.logical_reads, statements_stats.avg_logical_reads, statements_stats.stddev_logical_reads,statements.physical_reads, statements_stats.avg_physical_reads,statements_stats.stddev_physical_reads
from statements, statements_stats 
where statements_stats.sql_tag = statements.sql_tag and (((statements.wait_time > statements_stats.avg_wait_time + " . $stddev_factor ."*statements_stats.stddev_wait_time) AND (statements.wait_time >" . $wait_time_threshold . ")) or 
((statements.cpu_time > statements_stats.avg_cpu_time + " . $stddev_factor ."*statements_stats.stddev_cpu_time) AND (statements.cpu_time > " . $cpu_time_threshold .")) or 
((statements.logical_reads > statements_stats.avg_logical_reads + " . $stddev_factor ."*statements_stats.stddev_logical_reads) AND (statements.logical_reads > ". $lreads_threshold . ")) or 
((statements.physical_reads > statements_stats.avg_physical_reads + " . $stddev_factor ."*statements_stats.stddev_physical_reads) AND (statements.physical_reads > " . $preads_threshold . ")))
order by sql_tag";
    my $result = $sybase->query( query => $query);

    return unless $result;

    return @{ $result } ;
}

#-----------------------#
sub retrieve_mxml_nodes {
#-----------------------#
    my ( $self ) = @_;


    my $query = "select id, nodename, in_out, taskname, tasktype, sheetname, workflow, target_task, msg_taken_y, msg_taken_n, proc_time from mxml_nodes";
    my $result = $self->{oracle}->query( query => $query );
    return $result->all_rows;
}

#----------------------#
sub retrieve_mxml_node {
#----------------------#
    my ( $self, %args ) = @_;


    my $result;
    if ( my $id = $args{id} ) {
        my $query = "select rtrim(id), nodename, in_out, taskname, tasktype, sheetname, workflow, target_task, msg_taken_y, msg_taken_n, proc_time from mxml_nodes where rtrim(id) = ?";
        $result = $self->{oracle}->query( query => $query, values => [ $id ], quiet => 1 );
    }
    else {
        my $taskname = $args{taskname};
        my $nodename = $args{nodename};
        my $query = "select rtrim(id), nodename, in_out, taskname, tasktype, sheetname, workflow, target_task, msg_taken_y, msg_taken_n, proc_time from mxml_nodes where taskname = ? and nodename = ?";
        $result = $self->{oracle}->( query => $query, values => [ $taskname, $nodename ] );
    }

    return $result->nextref;
}

#-----------------------#
sub retrieve_mxml_tasks {
#-----------------------#
    my ( $self ) = @_;


    my $query = "select taskname, tasktype, sheetname, workflow, unblocked, loading_data, started, status, timestamp from mxml_tasks";
    my $result = $self->{oracle}->query( query => $query, quiet => 1 );
    return $result->all_rows;
}

#-----------------------#
sub retrieve_mxml_links {
#-----------------------#
    my ( $self, %args ) = @_;


    my $id = $args{id};

    my $query = "select target_task from mxml_links where id = ?";
    my $result = $self->{oracle}->query( query => $query, values => [ $id ], quiet => 1 );

    return map { $_->[0] } $result->all_rows;
}

#----------------------#
sub retrieve_mxml_task {
#----------------------#
    my ( $self, %args ) = @_;


    my $taskname = $args{taskname};

    my $query = "select taskname, tasktype, sheetname, workflow from mxml_nodes where taskname = ? and rownum = 1";
    my $result = $self->{oracle}->query( query => $query, values => [ $taskname ] );
    return $result->nextref;
}

#-----------------------------#
sub retrieve_mxml_directories {
#-----------------------------#
    my ( $self ) = @_;


    my $query = "select taskname, received, error from mxml_directories";
    my $result = $self->{oracle}->query( query => $query );
    return $result->all_rows;
}

#----------------------------#
sub retrieve_mxml_nodes_hist {
#----------------------------#
    my ( $self, %args ) = @_;


    my $begin_timestamp = $args{begin_timestamp};
    my $end_timestamp   = $args{end_timestamp};

    my $query = "select distinct(rtrim(id)) from mxml_nodes_hist where timestamp >= ? and timestamp <= ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $begin_timestamp, $end_timestamp ] );

    return map { $_->[0] } $result->all_rows;
}

#-----------------------------#
sub retrieve_mxml_nr_messages {
#-----------------------------#
    my ( $self, %args ) = @_;


    my $id              = $args{id};
    my $begin_timestamp = $args{begin_timestamp};
    my $end_timestamp   = $args{end_timestamp};

    my $query = "select timestamp, msg_taken_n from mxml_nodes_hist where rtrim(id) = ? and timestamp >= ? and timestamp <= ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $id, $begin_timestamp, $end_timestamp ] );

    return $result->all_rows;
}

#------------------------------#
sub retrieve_mxml_nr_messages2 {
#------------------------------#
    my ( $self, %args ) = @_;


    my $query = "select id, msg_taken_y, msg_taken_n, proc_time from mxml_nodes";
    my $result = $self->{oracle}->query( query => $query );
    return $result->all_rows;
}

#----------------------------#
sub retrieve_mxml_timestamps {
#----------------------------#
    my ( $self, %args ) = @_;


    my $begin_timestamp = $args{begin_timestamp};
    my $end_timestamp   = $args{end_timestamp};

    my $query = "select timestamp from mxml_nodes_hist where rtrim(id) = ? and timestamp >= ? and timestamp <= ? order by timestamp";

    my $result = $self->{oracle}->query( query => $query, values => [ 0, $begin_timestamp, $end_timestamp ] );

    return map { $_->[0] } $result->all_rows;
}

#----------------------------#
sub retrieve_logfile_extract {
#----------------------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};
    my $query  = "select id, timestamp, filename, type, extract, start_pos, length from logfiles where id = $id";
    my $result = $self->{oracle}->query( query => $query );
    return $result->nextref;
}

#------------------------#
sub retrieve_ab_sessions {
#------------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_ab_sessions';
    return $self->_retrieve( %args );
}

#-----------------------#
sub retrieve_ab_session {
#-----------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select id, rtrim(hostname), cmdline, starttime, endtime, nr_books_ok, nr_books_nok, rtrim(business_date), duration, sched_jobstream, batchname, pid from ab_sessions where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return $result->[0];
}

#---------------------#
sub retrieve_ab_books {
#---------------------#
    my ( $self, %args ) = @_;

    $args{stored_procedure} = 'sp_page_ab_books';
    return $self->_retrieve( %args );
}

#-----------------------#
sub retrieve_ab_timings {
#-----------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $sybase = $self->{sybase};
    my $query1  = "select sum(duration), sum(runtime), sum(cputime), sum(iotime) from sessions where ab_session_id = $id";
    my $result1 = $sybase->query( query => $query1 );
    my $query2  = "select sum(runtime), sum(est_runtime) from ab_books where ab_session_id = $id";
    my $result2 = $sybase->query( query => $query2 );
    return ( @{$result1->[0]}, @{$result2->[0]} ) ;
}

#---------------------------#
sub retrieve_ab_book_status {
#---------------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $sybase = $self->{sybase};
    my $query1  = "select count(*) from ab_books where ab_session_id = $id and status = 'READY'";
    my $result1 = $sybase->query( query => $query1 );
    my $query2  = "select count(*) from ab_books where ab_session_id = $id and status = 'RUNNING'";
    my $result2 = $sybase->query( query => $query2 );
    my $query3  = "select count(*) from ab_books where ab_session_id = $id and status = 'FINISHED'";
    my $result3 = $sybase->query( query => $query3 );
    my $query4  = "select count(*) from ab_books where ab_session_id = $id and status = 'FAILED'";
    my $result4 = $sybase->query( query => $query4 );
    my $query5  = "select count(*) from ab_books where ab_session_id = $id and status = 'ABORTED'";
    my $result5 = $sybase->query( query => $query5 );
    return ( $result1->[0][0], $result2->[0][0], $result3->[0][0], $result4->[0][0], $result5->[0][0] ) ;
}

#--------------------------------#
sub retrieve_unfinished_ab_books {
#--------------------------------#
    my ( $self, %args ) = @_;

    my $id = $args{id};
    my $query  = "select id from ab_books where ab_session_id = $id and status <> 'FINISHED'";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}

#--------------------------------#
sub retrieve_finished_ab_reports {
#--------------------------------#
    my ( $self, %args ) = @_;

    my $id = $args{id};
    my $query  = "select distinct(report_id) from ab_books where ab_session_id = $id and status = 'FINISHED'";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}

#------------------------#
sub retrieve_nr_books_ok {
#------------------------#
    my ( $self, %args ) = @_;

    my $id = $args{id};
    my $query  = "select nr_books_ok from ab_sessions where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return $result->[0][0];
}

#--------------------#
sub retrieve_ab_book {
#--------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select id, book, batch, ab_session_id, starttime, endtime, runtime, nr_runs, status, report_id, reference, est_runtime from ab_books where id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return $result->[0];
}

#----------------------------#
sub retrieve_linked_sessions {
#----------------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select session_id from ab_books_sessions where book_id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}

#-----------------------------#
sub retrieve_linked_sessions2 {
#-----------------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select id from sessions where ab_session_id = $id and mx_endtime = NULL";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}

#-------------------------#
sub retrieve_linked_books {
#-------------------------#
    my ( $self, %args ) = @_;
   
    my $id = $args{id};
    my $query  = "select book_id from ab_books_sessions where session_id = $id";
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}


#--------------------#
sub retrieve_timings {
#--------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query = 'select timestamp, id, context, command, elapsed, cpu, rdb from timings where session_id = ? order by timestamp, id';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#------------------------#
sub retrieve_performance {
#------------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query = 'select session_id, timestamp, usr, sys, trp, tfl, dfl, lck, slp, lat, vcx, icx, scl from performance where session_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#-------------------#
sub retrieve_memory {
#-------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query = 'select session_id, timestamp, vsize, rss, anon from memory where session_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#-------------------#
sub retrieve_dtrace {
#-------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query = "select session_id, library, function, ncount, cpu, elapsed from usercalls where session_id = ? order by elapsed desc";

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#---------------------#
sub retrieve_sqltrace {
#---------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query  = 'select session_id, name, tot_duration, avg_duration, type, ncount, percentage from sqltrace where session_id = ? order by percentage desc';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#------------------#
sub retrieve_sqlio {
#------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query  = 'select session_id, name, logical, physical from sqlio where session_id = ? order by logical desc';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#-------------------#
sub retrieve_sybase {
#-------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query  = 'select session_id, timestamp, cpu, io, mem from sybase where session_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->all_rows;
}

#-------------------------------#
sub retrieve_global_performance {
#-------------------------------#
    my ( $self, %args ) = @_;


    my $query  = "select * from global_performance";

    my $result = $self->{oracle}->query( query => $query );

    return $result->all_rows;
}

#---------------------------#
sub retrieve_linked_reports {
#---------------------------#
    my ( $self, %args ) = @_;
   
    my $query;
    if ( my $session_id = $args{session_id} ) {
        $query  = "select id from reports where session_id = $session_id";
    }
    elsif ( my $ab_session_id = $args{ab_session_id} ) {
        $query  = "select id from reports where ab_session_id = $ab_session_id";
    }
    my $sybase = $self->{sybase};
    my $result = $sybase->query( query => $query );
    return map { $_->[0] } @{$result};
}

#------------------------------#
sub retrieve_linked_dm_reports {
#------------------------------#
    my ( $self, %args ) = @_;

   
    my $script_id = $args{script_id};

    my $query = "select id from dm_reports where script_id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $script_id ] );

    return map { $_->[0] } $result->all_rows;
}

#--------------------------------#
sub retrieve_linked_feedertables {
#--------------------------------#
    my ( $self, %args ) = @_;

   
    my $session_id = $args{session_id};

    my $query  = "select id from feedertables where session_id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return map { $_->[0] } $result->all_rows;
}

#-----------------------------#
sub retrieve_linked_dm_filter {
#-----------------------------#
    my ( $self, %args ) = @_;

   
    my $session_id = $args{session_id};

    my $query  = "select id from dm_filters where session_id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    return $result->nextref->[0];
}

#-----------------#
sub retrieve_core {
#-----------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};

    my $query = 'select id, session_id, pstack_path, pmap_path, core_path, hostname, size, timestamp, win_user, mx_user, mx_group, mx_nick, function, business_date from cores where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#-------------------------#
sub retrieve_similar_core {
#-------------------------#
    my ( $self, %args ) = @_;


    my $id       = $args{id};
    my $function = $args{function};
    my $hostname = $args{hostname};

    my $query = 'select id, session_id, pstack_path, pmap_path, core_path, hostname, size, timestamp, win_user, mx_user, mx_group, mx_nick, function, business_date from cores where id <> ? and function = ? and hostname = ? and core_path is not null';

    my $result = $self->{oracle}->query( query => $query, values => [ $id, $function, $hostname ] );

    return $result->nextref;
}

#---------------#
sub update_core {
#---------------#
    my ( $self, %args ) = @_;
   

    my $id = $args{id};

    my $statement = 'update cores set core_path = null where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $id ] );
}

#--------------------#
sub retrieve_service {
#--------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = "select id, name, starttime, endtime, service_start_duration, service_start_rc, post_start_duration, post_start_rc, pre_stop_duration, pre_stop_rc, service_stop_duration, service_stop_rc, business_date from services where id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#------------------------------#
sub retrieve_service_processes {
#------------------------------#
    my ( $self, %args ) = @_;

   
    my $id = $args{id};

    my $query = "select label, hostname, pid, starttime, endtime, cpu_seconds, vsize from service_processes where service_id = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->all_rows;
}

#
# Arguments
#
# where          hashref containing the select criteria
# sort           hashref containing the sort criteria ( a true value for ascending, a false for descending)
# page_nr        which 'page' of results
# recs_per_page  nr of results per page
#
#-------------#
sub _retrieve {
#-------------#
    my ( $self, %args ) = @_;


    my $where_clause = '';
    if ( $args{where} && ref($args{where}) eq 'HASH' ) {
        my @and_components = ();
        my %where = %{$args{where}};
        while ( my ($key, $value) = each %where ) {
            if ( ref($value) eq 'ARRAY' ) {
                my @list = ();
                foreach my $entry ( @{$value} ) {
                    if ( $key =~ /^\*(.+)$/ ) {
                        push @list, "$1 like \"%$entry%\"";
                    } 
                    else {
                        push @list, "$key = $entry";
                    }
                }  
                push @and_components, ( join ' or ', @list );
            }
            elsif ( $value =~ /^<> / ) {
                push @and_components, "$key $value";
            }
            else {
                if ( $key =~ /^\*(.+)$/ ) {
                    push @and_components, "$1 like \"%$value%\"";
                } 
                else {
                    push @and_components, "$key = $value";
                }
            }
        }
        $where_clause = join ' and ', @and_components;
    }

    my $sort_clause = 'id';
    if ( $args{sort} && ref($args{sort}) eq 'HASH' ) {
        my @sort_components = ();
        my %sort = %{$args{sort}};
        while ( my ($key, $value) = each %sort ) {
            push @sort_components, $key . ( $value ? ' asc' : ' desc' );
        }
        $sort_clause = join ',', @sort_components;
    }

    my $page_nr          = $args{page_nr} || 1;
    my $recs_per_page    = $args{recs_per_page} || 30;
    my $stored_procedure = $args{stored_procedure};

    $where_clause =~ s/'/\\'/g;

    my $statement = "begin $stored_procedure($page_nr, $recs_per_page, '$sort_clause'," . ( $where_clause ? "'$where_clause'":"''" ) . ", ?:C); end;";

    $self->{logger}->debug($statement);

    my $cursor;
    my $result = $self->{oracle}->do( statement => $statement, nocache => 1, cr_values => [ \$cursor ] ); 

    return $cursor->fetchall_arrayref();
}

#
# Arguments
#
# session_id or ab_session_id or sql_tag and sql_library
#
#-----------------------#
sub record_report_start {
#-----------------------#
    my ( $self, %args ) = @_;


    my $label         = $args{label};
    my $type          = $args{type};
    my $path          = $args{path};
    my $batchname     = $args{batchname};
    my $reportname    = $args{reportname};
    my $entity        = $args{entity};
    my $runtype       = $args{runtype};
    my $mds           = $args{mds};
    my $status        = $args{status};
    my $filter        = $args{filter};
    my $sybase        = $self->{sybase};
    my $starttime     = time();
#    my $business_date = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date = Mx::Murex->calendardate();
    my $statement;
    if ( my $session_id = $args{session_id} ) {
        $statement  = "insert into reports (label, type, path, session_id, batchname, reportname, entity, runtype, mds, starttime, business_date, status, archived, compressed, filter) values ('$label', '$type', '$path', $session_id, '$batchname', '$reportname', '$entity', '$runtype', '$mds', $starttime, '$business_date', '$status', '0', '0', '$filter')";
    }
    elsif ( my $ab_session_id = $args{ab_session_id} ) {
        $statement  = "insert into reports (label, type, path, ab_session_id, batchname, reportname, entity, runtype, mds, starttime, business_date, status, archived, compressed) values ('$label', '$type', '$path', $ab_session_id, '$batchname', '$reportname', '$entity', '$runtype', '$mds', $starttime, '$business_date', '$status', '0', '0')";
    }
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#
# Arguments
#
# report_id
# size
# nr_records
#
#---------------------#
sub record_report_end {
#---------------------#
    my ( $self, %args ) = @_;
    
    my $sybase = $self->{sybase};
    my $statement = 'update reports set endtime = ?, size = ?, nr_records = ?, status = ? where id = ?';
    $sybase->do( statement => $statement, values => [ time(), $args{size}, $args{nr_records}, $args{status}, $args{id} ] );
}

#--------------------------#
sub record_dm_report_start {
#--------------------------#
    my ( $self, %args ) = @_;


    my $label         = $args{label};
    my $type          = $args{type};
    my $script_id     = $args{script_id};
    my $name          = $args{name};
    my $directory     = $args{directory};
    my $starttime     = $args{starttime};
    my $project       = $args{project};
    my $entity        = $args{entity};
    my $runtype       = $args{runtype};
#    my $business_date = Mx::Murex->businessdate( config => $self->{config}, logger => $self->{logger} );
    my $business_date = Mx::Murex->calendardate();

    my $statement = 'insert into dm_reports (id, label, type, script_id, name, directory, starttime, project, entity, runtype, business_date) values (dm_reports_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [$label, $type, $script_id, $name, $directory, $starttime, $project, $entity, $runtype, $business_date];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#------------------------#
sub record_dm_report_end {
#------------------------#
    my ( $self, %args ) = @_;
    

    my $statement = 'update dm_reports set endtime = ?, rsize = ?, nr_records = ? where id = ?';

    $self->{oracle}->do( statement => $statement, values => [ $args{endtime}, $args{size}, $args{nr_records}, $args{id} ] );
}

#--------------------#
sub update_dm_report {
#--------------------#
    my ( $self, %args ) = @_;

    
    if ( $args{name} ) {
        my $statement = 'update dm_reports set name = ? where id = ?';
        $self->{oracle}->do( statement => $statement, values => [ $args{name}, $args{id} ] );
    }
    elsif ( $args{directory} ) {
        my $statement = 'update dm_reports set directory = ? where id = ?';
        $self->{oracle}->do( statement => $statement, values => [ $args{directory}, $args{id} ] );
    }
    elsif ( $args{mode} ) {
        my $statement = 'update dm_reports set rmode = ?, rsize = ?, nr_records = ? where id = ?';
        $self->{oracle}->do( statement => $statement, values => [ $args{mode}, $args{size}, $args{nr_records}, $args{id} ] );
    }
}

#----------------------#
sub record_feedertable {
#----------------------#
    my ( $self, %args ) = @_;

   
    my $session_id  = $args{session_id};
    my $name        = $args{name};
    my $batch_name  = $args{batch_name};
    my $feeder_name = $args{feeder_name};
    my $entity      = $args{entity};
    my $runtype     = $args{runtype};
    my $tabletype   = $args{tabletype};
    my $timestamp   = time();
    my $job_id      = $args{job_id};
    my $ref_data    = $args{ref_data};
    my $nr_records  = $args{nr_records};

    my $statement = 'insert into feedertables (id, session_id, name, batch_name, feeder_name, entity, runtype, timestamp, job_id, ref_data, nr_records, tabletype) values (feedertables_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $session_id, $name, $batch_name, $feeder_name, $entity, $runtype, $timestamp, $job_id, $ref_data, $nr_records, $tabletype ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#--------------------#
sub record_dm_filter {
#--------------------#
    my ( $self, %args ) = @_;


    my $session_id    = $args{session_id};
    my $batch_name    = $args{batch_name};
    my $dates         = $args{dates};
    my $mds           = $args{mds};
    my $products      = $args{products};
    my $portfolios    = $args{portfolios};
    my $expression    = $args{expression};

    $dates      = join ':', @{$dates};
    $mds        = join ':', @{$mds};
    $products   = join ':', @{$products};
    $portfolios = join ':', @{$portfolios};

    my $statement = 'insert into dm_filters (id, session_id, batch_name, dates, mds, products, portfolios, expression) values (dm_filters_seq.nextval, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $session_id, $batch_name, $dates, $mds, $products, $portfolios, $expression ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#-----------------------#
sub record_scanner_info {
#-----------------------#
    my ( $self, %args ) = @_;


    my $session_id       = $args{session_id};
    my $nr_engines       = $args{nr_engines};
    my $batch_size       = $args{batch_size};
    my $nr_retries       = $args{nr_retries};
    my $nr_batches       = $args{nr_batches};
    my $nr_items         = $args{nr_items};
    my $nr_missing_items = $args{nr_missing_items};
    my $nr_table_records = $args{nr_table_records};

    my $query = 'select sum(runtime), sum(cputime), sum(iotime), sum(cpu_seconds) from sessions where ab_session_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    my ( $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds );
    unless ( ( $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds ) = $result->next ) {
        $self->{logger}->warn("no scanner engines found for session $session_id");
    }

    my $statement = 'insert into dm_scanners (id, session_id, nr_engines, batch_size, nr_retries, nr_batches, nr_items, nr_missing_items, nr_table_records, total_runtime, total_cputime, total_iotime, total_cpu_seconds) values (dm_scanners_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

    $self->{oracle}->do( statement => $statement, values => [ $session_id, $nr_engines, $batch_size, $nr_retries, $nr_batches, $nr_items, $nr_missing_items, $nr_table_records, $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds ] );

    if ( $nr_missing_items ) {
        my $missing_items_ref = $args{missing_items};

        $statement = "insert into dm_items (session_id, item_ref) values ($session_id, ?)";

        $self->{oracle}->do_multiple( sql => $statement, values => $missing_items_ref );
    } 
}

#------------------------#
sub record_scanner_info2 {
#------------------------#
    my ( $self, %args ) = @_;


    my $session_id       = $args{session_id};
    my $nr_engines       = $args{nr_engines};
    my $batch_size       = $args{batch_size};
    my $nr_retries       = $args{nr_retries};
    my $nr_batches       = undef;
    my $nr_items         = undef;
    my $nr_missing_items = undef;
    my $nr_table_records = $args{nr_table_records};

    my $query = 'select runtime, cputime, iotime, cpu_seconds from sessions where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    my ( $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds ) = $result->next;

    my $statement = 'insert into dm_scanners (id, session_id, nr_engines, batch_size, nr_retries, nr_batches, nr_items, nr_missing_items, nr_table_records, total_runtime, total_cputime, total_iotime, total_cpu_seconds) values (dm_scanners_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

    $self->{oracle}->do( statement => $statement, values => [ $session_id, $nr_engines, $batch_size, $nr_retries, $nr_batches, $nr_items, $nr_missing_items, $nr_table_records, $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds ] );
}

#-------------------------#
sub retrieve_scanner_info {
#-------------------------#
    my ( $self, %args ) = @_;


    my $session_id = $args{session_id};

    my $query = 'select nr_engines, batch_size, nr_retries, nr_batches, nr_items, nr_missing_items, nr_table_records, total_runtime, total_cputime, total_iotime, total_cpu_seconds from dm_scanners where session_id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

    my ( $nr_engines, $batch_size, $nr_retries, $nr_batches, $nr_items, $nr_missing_items, $nr_table_records, $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds ) = $result->next;

    my @missing_items = ();
    if ( $nr_missing_items ) {
        $query = 'select item_ref from dm_items where session_id = ?';

        $result = $self->{oracle}->query( query => $query, values => [ $session_id ] );

        @missing_items = map { $_->[0] } $result->all_rows;
    }

    return ( $nr_engines, $batch_size, $nr_retries, $nr_batches, $nr_items, $nr_missing_items, \@missing_items, $nr_table_records, $total_runtime, $total_cputime, $total_iotime, $total_cpu_seconds );
}

#---------------------------------#
sub retrieve_average_scanner_info {
#---------------------------------#
    my ( $self, %args ) = @_;


    my $mx_scriptname = $args{mx_scriptname};
    my $mx_scripttype = 'dm_batch';
    my $entity        = $args{entity};
    my $runtype       = $args{runtype};

    my $query = "select count(*), avg(nr_engines), avg(B.nr_table_records), avg(B.total_runtime), avg(B.total_cputime), avg(B.total_iotime), avg(B.total_cpu_seconds) from sessions A, dm_scanners B where A.id = B.session_id and A.mx_scriptname = ? and A.mx_scripttype = ? and A.entity = ?";

    my $result = $self->{oracle}->query( query => $query, values => [ $mx_scriptname, $mx_scripttype, $entity ], quiet => 1 );

    return $result->next;
}

#-------------------------------#
sub retrieve_average_batch_info {
#-------------------------------#
    my ( $self, %args ) = @_;


    my $mx_scriptname = $args{mx_scriptname};
    my $mx_scripttype = $args{mx_scripttype};
    my $entity        = $args{entity};
    my $runtype       = $args{runtype};
    my $sybase        = $self->{sybase};

    my $query = "select count(*), avg(runtime), avg(cputime), avg(iotime), avg(cpu_seconds) from sessions where mx_scriptname = ? and mx_scripttype = ? and entity = ?";

    my $result = $sybase->query( query => $query, values => [ $mx_scriptname, $mx_scripttype, $entity ], quiet => 1 );

    return @{$result->[0]};
}

#-----------------------------#
sub record_report_command_end {
#-----------------------------#
    my ( $self, %args ) = @_;
    
    my $sybase = $self->{sybase};
    my $statement = 'update reports set exitcode = ?, cduration = ? where id = ?';
    $sybase->do( statement => $statement, values => [ $args{exitcode}, $args{cduration}, $args{report_id} ] );
}

#---------------------#
sub record_bct_report {
#---------------------#
    my ( $self, %args ) = @_;

    my $dm_report_id  = $args{dm_report_id};
    my $environment   = $args{environment};
    my $name          = $args{name};
    my $directory     = $args{directory};
    my $nr_columns    = $args{nr_columns};
    my $separator     = $args{separator};
    my $timestamp     = $args{timestamp};
    my $win_user      = $args{win_user};
    my $comment       = $args{comment};

    my $sybase = $self->{sybase};

    my $statement  = "insert into bct_reports (dm_report_id, environment, name, directory, nr_columns, separator, timestamp, win_user, comment) values ($dm_report_id, '$environment', '$name', '$directory', $nr_columns, '$separator', $timestamp, '$win_user', '$comment')";
    $sybase->do( statement => $statement );
    my $result = $sybase->query( query => 'select @@identity' );
    return $result->[0][0];
}

#---------------------#
sub update_bct_report {
#---------------------#
    my ( $self, %args ) = @_;

    my $id         = $args{id};
    my $nr_records = $args{nr_records};
    my $size       = $args{size};

    my $sybase = $self->{sybase};

    my $statement = 'update bct_reports set nr_records = ?, size = ? where id = ?';
    $sybase->do( statement => $statement, values => [ $nr_records, $size, $id ] );
}

#--------------------------#
sub record_swift_message {
#--------------------------#
	my ( $self, %args ) = @_;

    my $sybase          = $self->{sybase};
	my $sendersref      = $args{sendersref};
	my $relatedref      = $args{relatedref};
	my $messagetype     = $args{messagetype};
	my $reasoncode      = $args{reasoncode};
	my $account         = $args{account};
	my $itemstate       = $args{itemstate};
	my $state           = $args{state};
	my $operationtype   = $args{operationtype};
	my $eventtype       = $args{eventtype};
	my $passnum         = $args{passnum};
	my $swapsendersref  = $args{swapsendersref};
	my $swapitemtype    = $args{swapitemtype};
	my $docid           = $args{docid};
	my $mxstatus        = $args{mxstatus};
	my $timestamp       = time();
	my $runid           = $args{runid};
	my $runstatus       = $args{runstatus};
	
	my $statement = 'insert into imswift_status (sendersref, relatedref, messagetype, reasoncode, account, itemstate, state, operationtype, eventtype, passnum, swapsendersref, swapitemtype, docid, mxstatus, timestamp, runid, runstatus) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
	$sybase->do( statement => $statement, values => [ $sendersref, $relatedref, $messagetype, $reasoncode, $account, $itemstate, $state, $operationtype, $eventtype, $passnum, $swapsendersref, $swapitemtype, $docid, $mxstatus, $timestamp, $runid, $runstatus ] );
}

#----------------#
sub record_alert {
#----------------#
    my ( $self, %args ) = @_;


    my $timestamp     = $args{timestamp};
    my $name          = $args{name};
    my $item          = $args{item};
    my $category      = $args{category};
    my $level         = $args{level};
    my $message       = $args{message};
    my $business_date = $args{business_date};
    my $ack_received  = $args{ack_received};
    my $logfile       = $args{logfile};

    my $statement = 'insert into alerts (id, timestamp, name, item, category, wlevel, message, business_date, ack_received, trigger_count, trigger_timestamp, logfile) values (alerts_seq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) returning id into ?:O';

    my $values = [ $timestamp, $name, $item, $category, $level, $message, $business_date, $ack_received, 1, $timestamp, $logfile ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

    return $id;
}

#-----------------#
sub trigger_alert {
#-----------------#
    my ( $self, %args ) = @_;


    my $id        = $args{id};
    my $message   = $args{message};
    my $timestamp = time();

    my $statement = "update alerts set message = ?, trigger_count = trigger_count + 1, trigger_timestamp = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ $message, $timestamp, $id ] );
}

#-------------#
sub ack_alert {
#-------------#
    my ( $self, %args ) = @_;


    my $id        = $args{id};
    my $user      = $args{user};
    my $timestamp = time();

    my $statement = "update alerts set ack_received = ?, ack_user = ?, ack_timestamp = ? where id = ?";

    $self->{oracle}->do( statement => $statement, values => [ 1, $user, $timestamp, $id ] );
}

#-----------------------#
sub retrieve_last_alert {
#-----------------------#
    my ( $self, %args ) = @_;


    my $name          = $args{name};
    my $item          = $args{item};
    my $level         = $args{level};
    my $business_date = $args{business_date};

    my $query = 'select * from ( select id, timestamp, ack_received, trigger_count from alerts where name = ? and item = ? and wlevel = ? and business_date = ? order by timestamp desc ) where rownum = 1';

    my $result = $self->{oracle}->query( query => $query, values => [ $name, $item, $level, $business_date ] );

    return $result->nextref;
}

#------------------#
sub retrieve_alert {
#------------------#
    my ( $self, %args ) = @_;


    my $id = $args{id};

    my $query  = 'select id, timestamp, name, item, category, wlevel, message, business_date, ack_received, ack_timestamp, ack_user, trigger_count, trigger_timestamp, logfile from alerts where id = ?';

    my $result = $self->{oracle}->query( query => $query, values => [ $id ] );

    return $result->nextref;
}

#--------------------------#
sub record_logfile_extract {
#--------------------------#
    my ( $self, %args ) = @_;
    

    my $statement = 'insert into logfiles ( id, timestamp, filename, type, extract, start_pos, length ) values ( logfiles_seq.nextval, ?, ?, ?, ?, ?, ? ) returning id into ?:O';

    my $values = [ $args{timestamp}, $args{filename}, $args{type}, $args{extract}, $args{start_pos}, $args{length} ];

	my $id;
    $self->{oracle}->do( statement => $statement, values => $values, io_values => [ \$id ] );

	return $id;
}

#
# Arguments
#
# session_id
#
#-----------------#
sub get_report_id {
#-----------------#
    my ( $self, %args ) = @_;
    
    my $sybase = $self->{sybase};
    my $session_id = $args{session_id};
    my ( $query, $result );
    $query = 'select max(id) from reports where session_id = ? and endtime = NULL';
    $result = $sybase->query( query => $query, values => [ $session_id ] );
    my $report_id = $result->[0][0];
    $query = 'select count(*) from reports where session_id = ?';
    $result = $sybase->query( query => $query, values => [ $session_id ] );
    my $nr_reports = $result->[0][0];
    return ( $report_id, $nr_reports );
}

#
# Arguments
#
# session_id
#
#------------------#
sub get_report_ids {
#------------------#
    my ( $self, %args ) = @_;
    
    my $sybase = $self->{sybase};
    my $session_id = $args{session_id};
    my ( $query, $result );
    $query = 'select id from reports where session_id = ? and endtime = NULL';
    $result = $sybase->query( query => $query, values => [ $session_id ] );
    return map { $_->[0] } @{$result};
}

#-------------------#
sub collect_timings {
#-------------------#
    my ( $self, %args ) = @_;

    
    my $session_id = $args{session_id};
    my $file       = $args{file};

    my $fh;
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $self->{logger}->error("cannot open timings file ($file): $!");
        return;
    }

    my $statement  = 'insert into timings (session_id, timestamp, id, context, command, elapsed, cpu, rdb) values (?, ?, ?, ?, ?, ?, ?, ?)';

    my $total_elapsed = 0; my $total_cpu = 0; my $total_rdb = 0; my $timestamp;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\d{8}\|/ ) {
            my @fields = split /\|/, $line;
            my ($date, $time, $id, $context, $command, $elapsed, $cpu, $rdb) = @fields[0,1,3,4,5,6,7,9];
            my $year  = substr($date, 0, 4) - 1900;
            my $month = substr($date, 4, 2) - 1;
            my $day   = substr($date, 6, 2);
            my ($hours, $min, $sec) = split ':', $time;
            $timestamp = timelocal($sec, $min, $hours, $day, $month, $year);
            $context =~ s/\s*$//;
            $command =~ s/\s*$//;
            $elapsed =~ s/s$//;
            $cpu     =~ s/s$//;
            $rdb     =~ s/s$//;

            $self->{oracle}->do( statement => $statement, values => [ $session_id, $timestamp, $id, $context, $command, $elapsed, $cpu, $rdb ] );

            unless ( $context =~ /sessioncreate/i or $context =~ /sessionkill/i or $context =~ /requestdocument/i ) {
                $total_elapsed += $elapsed;
                $total_cpu     += $cpu;
                $total_rdb     += $rdb;
            }
        }
    }

    $self->{oracle}->do( statement => $statement, values => [ $session_id, $timestamp + 1, 0, 'Totals', undef, $total_elapsed, $total_cpu, $total_rdb ] );

    $fh->close();
}

#----------------------#
sub record_start_delay {
#----------------------#
    my ( $self, %args ) = @_;


    my $session_id   = $args{session_id};
    my $file         = $args{file};

    my $fh;
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $self->{logger}->error("cannot open timings file ($file): $!");
        return;
    }

    my $statement = 'update sessions set start_delay = ? where id = ?';

    while ( my $line = <$fh> ) {
        if ( $line =~ /^\d{8}\|/ ) {
            my @fields = split /\|/, $line;

            my ($command, $elapsed) = @fields[5,6];

            next unless $command =~ /^SPBActUserLogin\s*/;

            $elapsed =~ s/s$//;

            $elapsed = int( $elapsed + 1 );

            $self->{oracle}->do( statement => $statement, values => [ $elapsed, $session_id ] );

            $fh->close();

            return $elapsed;
        }
    }

    $fh->close();

    return;
}

#-----------------------#
sub collect_performance {
#-----------------------#
    my ( $self, %args ) = @_;
    
    my $sybase     = $self->{sybase};
    my $session_id = $args{session_id};
    my $pid        = $args{pid};
    my $file       = $args{file};
    my $timestamp  = $args{start};
    my $interval   = $args{interval};
    my $fh;
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $self->{logger}->error("cannot open timings file ($file): $!");
        return;
    }
    my $statement = 'insert into performance (session_id, timestamp, usr, sys, trp, tfl, dfl, lck, slp, lat, vcx, icx, scl) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s+$pid\s+/ ) {
            my @fields = split ' ', $line;
            my ($usr, $sys, $trp, $tfl, $dfl, $lck, $slp, $lat, $vcx, $icx, $scl ) = @fields[ 2..12];
            foreach my $value ($vcx, $icx, $scl) {
                $value =~ s/^(.*)K/$1 * 1000/e;
                $value =~ s/^(.*)M/$1 * 1000 * 1000/e;
            }
            $sybase->do( statement => $statement, values => [ $session_id, $timestamp, $usr, $sys, $trp, $tfl, $dfl, $lck, $slp, $lat, $vcx, $icx, $scl ] );
            $timestamp += $interval;
        }
    }
    $fh->close();
}

#------------------#
sub collect_memory {
#------------------#
    my ( $self, %args ) = @_;

    
    my $session_id = $args{session_id};
    my $file       = $args{file};

    my $fh;
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $self->{logger}->error("cannot open memory file ($file): $!");
        return;
    }

    my $statement = 'insert into memory (session_id, timestamp, vsize, rss, anon) values (?, ?, ?, ?, ?)';

    while ( my $line = <$fh> ) {
        my ( $timestamp, $vsize, $rss, $anon ) = split ':', $line;
        $self->{oracle}->do( statement => $statement, values => [ $session_id, $timestamp, $vsize, $rss, $anon ] );
    }

    $fh->close();
}

#------------------#
sub collect_dtrace {
#------------------#
    my ( $self, %args ) = @_;
    

    my $session_id = $args{session_id};
    my $library    = $args{library};
    my $file       = $args{file};
    my $tooldir    = $self->{config}->TOOLDIR;

    unless ( -e $file ) {
        $self->{logger}->error("dtrace file ($file) does not exist");
        return;
    } 

    my $nr_retries = 0;
    while( -z $file && $nr_retries++ < 10 ) {
        sleep 1;
    }

    if ( -z $file ) {
        $self->{logger}->error("dtrace file ($file) is empty");
        unlink($file);
        return;
    }

    unless ( open CMD, "$tooldir/c++filt $file |" ) {
        $self->{logger}->error("cannot open dtrace file ($file): $!");
        return;
    }

    my %values; my %values2;
    while ( my $line = <CMD> ) {
       if ( $line =~ /^(A|B|C):\w+[ *](\w+)\(.*\):(\d+)$/ ) {
           $values{$2}->{$1} = $3;
       }
       elsif( $line =~ /^D:(\S+)`\w+[ *](.+)\(.*\)\+0x\w+:(\d+)$/ ) {
           $values2{$1}->{$2} = $3;
       }
    }

    CORE::close(CMD);

    my $nr_queries = 0;    
    my $statement  = 'insert into usercalls (session_id, library, function, ncount, cpu, elapsed) values (?, ?, ?, ?, ?, ?)';
    foreach my $function ( keys %values ) {
        my $ncount  = $values{$function}->{A};
        my $cpu     = $values{$function}->{B};
        my $elapsed = $values{$function}->{C};
        $self->{oracle}->do( statement => $statement, values => [ $session_id, $library, $function, $ncount, $cpu, $elapsed ] );
        if ( $function eq 'CTLIB_RequestExecuteWithParameters' or $function eq 'CTLIB_RequestExecute' ) {
            $nr_queries += $ncount;
        }
    }

    $statement  = 'insert into usercalls (session_id, library, function, ncount) values (?, ?, ?, ?)';
    foreach my $library ( keys %values2 ) {
        while ( my ( $function, $ncount ) = each %{$values2{$library}} ) {
            $self->{oracle}->do( statement => $statement, values => [ $session_id, $library, $function, $ncount ] );
        } 
    }

    unlink($file);

    return $nr_queries;
}

#------------------#
sub collect_sybase {
#------------------#
    my ( $self, %args ) = @_;

    my $sybase     = $self->{sybase};
    my $session_id = $args{session_id};
    my $file       = $args{file};
    my $fh;
    my $statement = 'insert into sybase (session_id, timestamp, cpu, io, mem) values (?, ?, ?, ?, ?)';
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $self->{logger}->error("cannot open sybase file ($file): $!");
        return;
    }
    my ( $total_cpu, $total_io, $total_mem ) = ( 0, 0, 0 );
    my %prev_cpu  = ();
    my $prev_time = 0;
    while ( my $line = <$fh> ) {
        chomp($line);
        if ( $line =~ /^\s*(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\s+([0-9 ]+)$/ ) {
            my $year   = $1 - 1900;
            my $month  = $2 - 1;
            my $day    = $3;
            my $hour   = $4;
            my $min    = $5;
            my $sec    = $6;
            my $time   = timelocal( $sec, $min, $hour, $day, $month, $year );
            my ($spid, $cpu, $io, $mem) = split ' ', $7;
            if ( $time != $prev_time && $prev_time ) {
                $sybase->do( statement => $statement, values => [ $session_id, $prev_time, $total_cpu, $total_io, $total_mem ] );
                $total_cpu = $total_io = $total_mem = 0;
            }
            $total_io  += $io;
            $total_mem += $mem;
            my $prev_cpu = $prev_cpu{$spid} || 0;
            if ( $cpu > $prev_cpu ) {
                $total_cpu += $cpu - $prev_cpu;
            }
            elsif ( $cpu < $prev_cpu ) {
                $total_cpu += $cpu;
            }
            $prev_cpu{$spid} = $cpu;
            $prev_time = $time;
        }
        else {
            $self->{logger}->warn("non-standard line: $line");
        }
    }
    $fh->close();
}

#--------------------#
sub collect_sqltrace {
#--------------------#
    my ( $self, %args ) = @_;


    my $config      = $self->{config};
    my $sourcefile  = $args{file};
    my $session_id  = $args{session_id};
    my $sqltracedir = $config->retrieve('SQLTRACEDIR');
    my $tooldir     = $config->retrieve('TOOLDIR');
    my $targetfile  = $sqltracedir . '/' . $session_id . '.trc';

    unless ( copy( $sourcefile, $targetfile ) ) {
        $self->{logger}->error("unable to copy $sourcefile to $targetfile: $!");
        return;
    }

    system("rdb_times $targetfile");
    my $resultfile = $targetfile . '.result.txt';
    my $statement = 'insert into sqltrace (session_id, name, tot_duration, avg_duration, type, ncount, percentage) values (?, ?, ?, ?, ?, ?, ?)';

    my $fh;
    unless ( $fh = IO::File->new( $resultfile, '<' ) ) {
        $self->{logger}->error("cannot open sqltrace file ($resultfile): $!");
        return;
    }

    while ( my $line = <$fh> ) {
        chomp($line);
        if ( $line =~ /^(.+?)\s+[0-9.]+\s+([0-9:.]+)\s+([0-9:.]+)\s+(\w+)\s+(\d+)\s+([0-9.]+)%/ ) {
            my $name = $1;
            next if $name eq 'TOTAL'; 
            my $ncount       = $5;
            next if $ncount == 0;
            my $tot_duration = _convert_duration($2);
            my $avg_duration = _convert_duration($3);
            my $type         = $4;
            my $percentage   = $6;
            $self->{oracle}->do( statement => $statement, values => [ $session_id, $name, $tot_duration, $avg_duration, $type, $ncount, $percentage ] );
        }
    }
    $fh->close;
    unlink($resultfile);
    return 1;
}

#-----------------#
sub collect_sqlio {
#-----------------#
    my ( $self, %args ) = @_;


    my $config      = $self->{config};
    my $session_id  = $args{session_id};
    my $sqltracedir = $config->retrieve('SQLTRACEDIR');
    my $tooldir     = $config->retrieve('TOOLDIR');
    my $targetfile  = $sqltracedir . '/' . $session_id . '.trc';

    system("rdb_io $targetfile 0");
    my $resultfile = $targetfile . '.io.txt';

    my $fh;
    unless ( $fh = IO::File->new( $resultfile, '<' ) ) {
        $self->{logger}->error("cannot open sqlio file ($resultfile): $!");
        return;
    }

    my %entries = ();
    while ( my $line = <$fh> ) {
        chomp($line);
        if ( $line =~ /^(.+?)\s+\d*\s+(\d+)\s+(\d+)\s*$/ ) {
            my $name = $1;
            $entries{$name}->{logical}  += $2;
            $entries{$name}->{physical} += $3;
        }
    }
    $fh->close;
    unlink($resultfile);

    my $statement = 'insert into sqlio (session_id, name, logical, physical) values (?, ?, ?, ?)';
    while ( my ( $name, $entry ) = each %entries ) {
        $self->{oracle}->do( statement => $statement, values => [ $session_id, $name, $entry->{logical}, $entry->{physical} ] );
    }

    return 1;
}

#---------------------#
sub _convert_duration {
#---------------------#
    my ( $duration ) = @_;

    my $cduration = 0;
    if ( $duration =~ /^(\d\d):(\d\d):(\d\d)\.(\d\d\d)$/ ) {
        $cduration = $1 * 3600000 + $2 * 60000 + $3 * 1000 + $4;
    }  
    return $cduration;
}

#------------------------------#
sub collect_global_performance {
#------------------------------#
    my ( $self, %args ) = @_;


    my $config     = $self->{config};
    my $nr_samples = $args{nr_samples};
    my $interval   = $args{interval};
    my $command    = $ENV{MXCOMMON} . '/' . $ENV{MXVERSION} . "/bin/sysperfstat.pl $interval $nr_samples";
    unless ( open CMD, "$command|" ) {
        return;
    }
    <CMD>; # skip the first line
    while ( my $line = <CMD> ) {
        chomp($line);
        my @values = split ':', $line;
        my $statement = 'insert into global_performance (timestamp, ucpu, umem, udisk, unet, scpu, smem, sdisk, snet) values (?, ?, ?, ?, ?, ?, ?, ?, ?)'; 
        $self->{oracle}->do( statement => $statement, values => \@values );
    }
    CORE::close(CMD);
}

#--------------------#
sub cleanup_sessions {
#--------------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;

    $logger->info("cleaning up sessions older than $retention days");

    my $result      = $sybase->query( query => "select id from sessions where mx_starttime < ? or req_starttime < ?", values => [ $threshold, $threshold ] );
    my @ids         = map { $_->[0] } @{$result};
    my $nr_sessions = @ids;

    $logger->info("starting deletion of $nr_sessions sessions");

    my $total = 0;
    foreach my $id ( @ids ) {
        $total += $sybase->do( statement => "delete sessions where id = ?", values => [ $id ] );
    }

    $logger->info("$total sessions cleaned up");

    return @ids;
}

#-------------------#
sub cleanup_scripts {
#-------------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up scripts older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete scripts where starttime < ?", values => [ $threshold ] );
    $logger->info("$nr_rows scripts cleaned up");
}

#--------------------#
sub cleanup_runtimes {
#--------------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up runtimes older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete runtimes where starttime < ?", values => [ $threshold ] );
    $logger->info("$nr_rows runtimes cleaned up");
}

#----------------#
sub cleanup_jobs {
#----------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up jobs older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete jobs where starttime < ?", values => [ $threshold ] );
    $logger->info("$nr_rows jobs cleaned up");
}

#---------------------------#
sub cleanup_mxml_nodes_hist {
#---------------------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up MxML entries older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete mxml_nodes_hist where timestamp < ?", values => [ $threshold ] );
    $logger->info("$nr_rows MxML enries cleaned up");
}

#----------------------#
sub cleanup_statements {
#----------------------#
    my ( $self, %args ) = @_;

   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;

    $logger->info("cleaning up statements older than $retention days");

    my $result        = $sybase->query( query => "select id from statements where starttime < ?", values => [ $threshold ] );
    my @ids           = map { $_->[0] } @{$result};
    my $nr_statements = @ids;

    $logger->info("starting deletion of $nr_statements statements");

    my $total = 0;
    foreach my $id ( @ids ) {
        $total += $sybase->do( statement => "delete statements where id = ?", values => [ $id ] );
    }

    $logger->info("$total statements cleaned up");

    return @ids;
}

#--------------------#
sub cleanup_logfiles {
#--------------------#
    my ( $self, %args ) = @_;
   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up logfile extracts older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete logfiles where timestamp < ?", values => [ $threshold ] );
    $logger->info("$nr_rows logfile extracts cleaned up");
}

#-----------------------#
sub cleanup_ab_sessions {
#-----------------------#
    my ( $self, %args ) = @_;
   
    my $sybase    = $self->{sybase};
    my $logger    = $self->{logger};
    my $retention = $args{retention};
    my $threshold = time() - $retention * 86400;
    $logger->info("cleaning up autobalance sessions older than $retention days");
    my $nr_rows = $sybase->do( statement => "delete ab_sessions where starttime < ?", values => [ $threshold ] );
    $logger->info("$nr_rows autobalance sessions cleaned up");
}

#----------#
sub report {
#----------#
    my ( $self ) = @_;

    my $sybase = $self->{sybase};
    my $logger = $self->{logger};
    foreach my $table ( qw( sessions reports timings performance sybase usercalls syscalls sqltrace sqlio logfiles runtimes mxml_nodes_hist ) ) {
        my $result = $sybase->query( query => "select count(*) from $table" );
        my $nr_rows = $result->[0][0];
        $logger->info("table $table: $nr_rows rows");
    }
}

#---------------------------#
sub increment_session_count {
#---------------------------#
    my ( $self, %args ) = @_;

   
    my $logger        = $self->{logger};
    my $win_user      = $args{win_user};
    my $mx_scripttype = $args{mx_scripttype};
    my $hostname      = $args{hostname};

    my $result = $self->{oracle}->query( query => "select ncount from session_count where win_user = ? and mx_scripttype = ? and hostname = ?", values => [ $win_user, $mx_scripttype, $hostname ] );

    my @rows = $result->all_rows;

    my $statement; my $count;
    if ( @rows ) {
        $count = $rows[0][0] + 1;
        $statement = 'update session_count set ncount = ? where win_user = ? and mx_scripttype = ? and hostname = ?';
        $self->{oracle}->do( statement => $statement, values => [ $count, $win_user, $mx_scripttype, $hostname ] );
    }
    else {
        $count = 1;
        $statement = 'insert into session_count (win_user, mx_scripttype, hostname, ncount) values (?, ?, ?, ?)';
        $self->{oracle}->do( statement => $statement, values => [ $win_user, $mx_scripttype, $hostname, $count ] );
    }

    $logger->debug("number of sessions of $win_user on $hostname incremented ($count)") if $win_user;
}

#---------------------------#
sub decrement_session_count {
#---------------------------#
    my ( $self, %args ) = @_;

   
    my $logger        = $self->{logger};
    my $win_user      = $args{win_user};
    my $mx_scripttype = $args{mx_scripttype};
    my $hostname      = $args{hostname};

    my $result = $self->{oracle}->query( query => "select ncount from session_count where win_user = ? and mx_scripttype = ? and hostname = ?", values => [ $win_user, $mx_scripttype,  $hostname ] );

    my @rows = $result->all_rows;

    my $statement; my $count;
    if ( @rows ) {
        $count = $rows[0][0] - 1;

        if ( $count > 0 ) {
            $statement = 'update session_count set ncount = ? where win_user = ? and mx_scripttype = ? and hostname = ?';
            $self->{oracle}->do( statement => $statement, values => [ $count, $win_user, $mx_scripttype, $hostname ] );
        }
        else {
            $statement = 'delete from session_count where win_user = ? and mx_scripttype = ? and hostname = ?';
            $self->{oracle}->do( statement => $statement, values => [ $win_user, $mx_scripttype, $hostname ] );
        }
    }

    $logger->debug("number of sessions of $win_user on $hostname decremented ($count)") if $win_user;
}

#--------------------------#
sub rebuild_session_counts {
#--------------------------#
    my ( $self, %args ) = @_;

   
    my $sessions = $args{sessions};

    $self->{oracle}->do( statement => 'truncate table session_count' );

    my $statement = 'insert into session_count (win_user, mx_scripttype, hostname, ncount ) values (?, ?, ?, ?)';

    foreach my $session ( @{$sessions} ) {
        my $win_user      = $session->{win_user};
        my $mx_scripttype = $session->{mx_scripttype};
        my $hostname      = $session->{hostname};
        my $count         = $session->{count};

        $self->{oracle}->do( statement => $statement, values => [ $win_user, $mx_scripttype, $hostname, $count ] );
    }
}

#--------------------------#
sub retrieve_session_count {
#--------------------------#
    my ( $self, %args ) = @_;


    my $win_user = $args{win_user};

    my $result = $self->{oracle}->query( query => 'select sum(ncount) from session_count where win_user = ?', values => [ $win_user ] );
    return $result->nextref->[0] || 0;
}

#--------------------------------#
sub retrieve_user_session_counts {
#--------------------------------#
    my ( $self ) = @_;


    my %sessions  = ();

    my $result = $self->{oracle}->query( query => "select rtrim(win_user), rtrim(hostname), ncount from session_count where win_user <> ''" );

    while ( my ($win_user, $hostname, $count) = $result->next ) {
        $sessions{$win_user} += $count;
        $sessions{$hostname} += $count;
    }

    return %sessions;
}

#---------------------------#
sub retrieve_session_counts {
#---------------------------#
    my ( $self ) = @_;


    my $result = $self->{oracle}->query( query => 'select rtrim(mx_scripttype), rtrim(hostname), sum(ncount) from session_count group by mx_scripttype, hostname', quiet => 1 );

    my %sessions  = ();
    while ( my ($mx_scripttype, $hostname, $count) = $result->next ) {
        $sessions{$mx_scripttype}->{$hostname} = $count;
    }

    return %sessions;
}

#-------------------#
sub record_resource {
#-------------------#
    my ( $self, %args ) = @_;


    my $sybase = $self->{sybase};
    my $name   = $args{name};
    my $value  = $args{value};

    my $statement = "update resourcepool set initial_size = ?, available = ? where resourcename = ?";
    my $nr_rows = $sybase->do( statement => $statement, values => [ $value, $value, $name ] );

    unless ( $nr_rows == 1 ) {
        $statement = "insert into resourcepool (resourcename, initial_size, available) values (?, ?, ?)";
        $sybase->do( statement => $statement, values => [ $name, $value, $value ] );
    }
}

#-------------------#
sub update_resource {
#-------------------#
    my ( $self, %args ) = @_;


    my $sybase    = $self->{sybase};
    my $name      = $args{name};
    my $value     = $args{value};
    my $increment = $args{increment};

    if ( ! defined $increment ) {
        my $statement = "update resourcepool set available = ? where resourcename = ?";
        $sybase->do( statement => $statement, values => [ $value, $name ] );
    }
    elsif ( $increment > 0 ) {
        my $statement = "update resourcepool set available = available + ? where resourcename = ?";
        $sybase->do( statement => $statement, values => [ $increment, $name ] );
    }
    elsif ( $increment < 0 ) {
        $increment = abs( $increment );
        my $statement = "update resourcepool set available = available - ? where resourcename = ?";
        $sybase->do( statement => $statement, values => [ $increment, $name ] );
    }
}

#----------------------#
sub retrieve_resources {
#----------------------#
    my ( $self, %args ) = @_;


    my $sybase    = $self->{sybase};
    my $name      = $args{name};

    my $result;
    if ( $name ) {
        my $query = "select resourcename, initial_size, available from resourcepool where resourcename = ?";
        $result = $sybase->query( query => $query, values => [ $name ], quiet => 1 );
    }
    else {
        my $query = "select resourcename, initial_size, available from resourcepool";
        $result = $sybase->query( query => $query, quiet => 1 );
    }

    my @resources = ();
    foreach my $row ( @{$result} ) {
        push @resources, { name => $row->[0], initial_size => $row->[1], value => $row->[2] };
    }

    return @resources;
}

#-----------------------#
sub get_distinct_values {
#-----------------------#
    my ( $self, %args ) = @_;


    my $table  = $args{table};
    my $column = $args{column};

    my $query  = "select distinct($column) from $table";

    my $result = $self->{oracle}->query( query => $query );

    return map { $_->[0] } $result->all_rows;
}

#---------------------#
sub _compress_cmdline {
#---------------------#
    my ( $cmdline, $config ) = @_;


#    my $to_replace  = $config->MXENV_ROOT;
#    my $replacement = '~';
#    $cmdline =~ s/$to_replace/$replacement/g;
    return $cmdline;
}

#-----------------------#
sub _decompress_cmdline {
#-----------------------#
    my ( $cmdline, $config ) = @_;


#    my $to_replace  = '~';
#    my $replacement = $config->MXENV_ROOT;
#    $cmdline =~ s/$to_replace/$replacement/g;
    return $cmdline;
}

1;

__END__

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    

# Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

					    
=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT


A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

					
=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.


=head1 AUTHOR

<Author name(s)>
