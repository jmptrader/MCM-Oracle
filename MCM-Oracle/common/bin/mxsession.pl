#!/usr/bin/env perl

BEGIN {
    open LOG, ">>mxsession.log";
    select LOG;
    $| = 1;
    *STDOUT = *LOG;
    *STDERR = *LOG;
}

use strict;
use warnings;

use sigtrap 'handler' => \&ignore;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Error;
use Mx::Audit;
use Mx::Process;
use Mx::Service;
use Mx::Auth::DB;
use Mx::Auth::Environment;
use Mx::Auth::User;
use Mx::Auth::Group;
use Mx::Auth::Right;
use Mx::DBaudit;
use Mx::Util;
use Mx::Alert;
use Mx::Semaphore;
use Mx::Message;
use Mx::Datamart::Scannerlog;
#use Mx::ResourcePool;
use File::Basename;
use File::Copy;
use POSIX qw(:sys_wait_h);

my $hostname = Mx::Util->hostname();

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new(directory => $config->LOGDIR, keyword => 'mxsession');

my $logfile = $logger->filename;
open STDERR, ">>$logfile";
select STDERR;
$| = 1;
open STDOUT, ">>$logfile";
select STDOUT;
$| = 1;

#
# initialize auditing
#
my $audit = Mx::Audit->new(directory => $config->AUDITDIR, keyword => 'mxsession', logger => $logger);

#
# make a (long) string out of all the commandline arguments
#
my $args = "@ARGV";

my $mx_starttime = time();

#
# from that commandline, extract some details about the session going to be started
#
my ($win_user, $mx_client_host, $mx_client_ip, $mx_nick, $mx_pid, $mx_user, $mx_group, $mx_desk, $app_user, $app_group, $app_desk, $mx_scriptname, $mx_scripttype, $mx_scanner, $mx_sessionid, $mx_noaudit, $entity, $runtype);

my $own_process = Mx::Process->new( logger => $logger, config => $config );

$own_process->analyze_cmdline();

$win_user       = $own_process->win_user || '';
$mx_client_host = $own_process->mx_client_host;
$mx_client_ip   = $own_process->mx_client_ip;
$mx_nick        = $own_process->mx_nick;
$mx_pid         = $own_process->mx_pid;
$mx_user        = $own_process->mx_user;
$mx_group       = $own_process->mx_group;
$mx_desk        = $own_process->mx_desk;
$app_user       = $own_process->app_user;
$app_group      = $own_process->app_group;
$app_desk       = $own_process->app_desk;
$mx_scripttype  = $own_process->mx_scripttype;
$mx_scanner     = $own_process->mx_scanner;
$mx_scriptname  = $own_process->mx_scriptname;
$mx_sessionid   = $own_process->mx_sessionid;
$entity         = $own_process->entity;
$runtype        = $own_process->runtype;
$mx_noaudit     = $own_process->mx_noaudit;

#
# do some quoting in case group or desk contain spaces
#
if ( $mx_group && $mx_group =~ / / ) {
    $args =~ s/\/GROUP:$mx_group/\/GROUP:"$mx_group"/;
}
if ( $app_group && $app_group =~ / / ) {
    $args =~ s/\/APPLICATION_GROUP:$app_group/\/APPLICATION_GROUP:"$app_group"/;
}
if ( $mx_desk && $mx_desk =~ / / ) {
    $args =~ s/\/DESK:$mx_desk/\/DESK:"$mx_desk"/;
}
if ( $app_desk && $app_desk =~ / / ) {
    $args =~ s/\/APPLICATION_DESK:$app_desk/\/APPLICATION_DESK:"$app_desk"/;
}

#
# mark the start of the session in the commandline
#
unless ( $mx_noaudit ) {
    if ( $mx_scriptname ) {
        $audit->start("scripttype $mx_scripttype, scriptname $mx_scriptname, nick $mx_nick, mx_pid $mx_pid");
    }
    elsif ( $win_user ) {
        $audit->start("nick $mx_nick, user $win_user, host $mx_client_host, ip $mx_client_ip, mx_pid $mx_pid");
    }
    else {
        $audit->start("nick $mx_nick, mx_pid $mx_pid");
    }
}

#
# lookup the nick in the configuration file
#
my $session_info;
unless ( $session_info = $config->retrieve("%SESSIONS%$mx_nick", 1) ) {
    $audit->end("nick $mx_nick cannot be found in the configuration file", 1);
}

my $binary         = $session_info->{binary};
my $params         = $session_info->{params};
my %env            = %{$session_info->{environment}};
my $allowed_groups = $session_info->{allowed_groups};
my @allowed_groups = ();
if ( $allowed_groups ) {
    @allowed_groups = split ',', $allowed_groups;
}

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#my $resourcepool = Mx::ResourcePool->new( config => $config, logger => $logger, db_audit => $db_audit );

my $user = undef; my $environment = undef;
if ( $win_user && $win_user !~ /^murex/ ) {
    #
    # check if the server is currently disabled
    #
    my $enabled = Mx::Service->check_access( $config, $logger );

    my $auth_db = Mx::Auth::DB->new( config => $config, logger => $logger );

    if ( $auth_db ) {
        $environment = Mx::Auth::Environment->new( name => $ENV{MXENV}, db => $auth_db, config => $config, logger => $logger );

        if ( $environment->retrieve ) {
            $user = Mx::Auth::User->new( name => $win_user, db => $auth_db, config => $config, logger => $logger);

            if ( $user->retrieve ) {
                if ( ! $enabled ) {
                    unless ( $user->check_right( name => 'override_disabled_env', environment => $environment ) ) {
                        my $message = Mx::Message->new(
                          destination => $ENV{MXENV},
                          message     => "Environment " . $ENV{MXENV} . " is disabled. Please contact support if you have questions.",
                          priority    => $Mx::Message::PRIO_HIGH,
                          db_audit    => $db_audit,
                          config      => $config,
                          logger      => $logger
                        );

                        $message->send;

                        $audit->end("the environment is disabled and user $win_user is not allowed to override", 1);
                    }
                }

                unless ( $user->check_right( name => 'murex_login', environment => $environment ) ) {
                    my $message = Mx::Message->new(
                      destination => $ENV{MXENV},
                      message     => "You are not authorized to start a session on " . $ENV{MXENV},
                      priority    => $Mx::Message::PRIO_HIGH,
                      db_audit    => $db_audit,
                      config      => $config,
                      logger      => $logger
                    );

                    $message->send;

                    $audit->end("user $win_user is not allowed to start a Murex session", 1);
                }
            }
            else {
                $user = undef;
            }
        }
        else {
            $environment = undef;
        }

        $auth_db->close;
    }

    my $current_session_count = $db_audit->retrieve_session_count( win_user => $win_user );
    $logger->info("user $win_user has currently $current_session_count session(s)");

    my $max_sessions = $config->MAX_SESSIONS;
    if ( $current_session_count >= $max_sessions ) {
        unless ( $user && $user->check_right( name => 'override_max_sessions', environment => $environment ) ) {
            my $message = Mx::Message->new(
              destination => $ENV{MXENV},
              message     => "You have reached the maximum session count ($max_sessions)",
              priority    => $Mx::Message::PRIO_HIGH,
              db_audit    => $db_audit,
              config      => $config,
              logger      => $logger
            );

            $message->send;

            $audit->end("maximum session count ($max_sessions) reached for user $win_user", 1);
        }
    }

    $mx_scripttype ||= 'user session';
}

$db_audit->increment_session_count( win_user => $win_user, mx_scripttype => $mx_scripttype, hostname => $hostname );

#$resourcepool->acquire( mx_scripttype => $mx_scripttype, mx_scriptname => $mx_scriptname, mx_scanner => $mx_scanner, entity => $entity, runtype => $runtype ) unless $mx_scripttype eq 'scanner';

#
# get the list of mx users which are only allowed to connect via a single session
#
my @single_session_users = ();
my $ref = $config->retrieve( 'SINGLE_SESSION_USER', 1 );
if ( $ref ) {
  if ( ref($ref) eq 'ARRAY' ) {
      @single_session_users = @{$ref};
  }
  else {
      @single_session_users = ( $ref );
  }
}

#
# set the necessary environment variables
#
while ( my ($variable, $value) = each %env ) {
    $ENV{$variable} = $value;
    $logger->debug("environment variable $variable set to $value");
}

#
# in case the session executes a batch , pass along the name of the outputfile 
# or/and the name of the user executing the batch
#
$ENV{MXRUSER}      = $win_user if $win_user;
$ENV{MXSCRIPTNAME} = $mx_scriptname if $mx_scriptname;
#$ENV{MXUSER}      = $mx_user if $mx_user;
$ENV{MXGROUP}      = $mx_group if $mx_group;
$ENV{MXDESK}       = $mx_desk if $mx_desk;

#
# build the command
#
my $directory = $config->MXENV_ROOT;
my $log_args  = '/STDOUT:logs/sessions/__MXID__.stdout /STDERR:logs/sessions/__MXID__.stdout';
my $command   = "$binary $log_args $args $params";

my $session_id;
if ( $mx_sessionid ) {
    $session_id = $mx_sessionid;
    $db_audit->update_session( session_id => $session_id, hostname => $hostname, cmdline => $command );
}
elsif ( ! $mx_noaudit ) {
    $session_id = $db_audit->record_session_mx_start( cmdline => $command, hostname => $hostname, mx_starttime => $mx_starttime, mx_scripttype => $mx_scripttype, mx_scriptname => $mx_scriptname, mx_nick => $mx_nick, win_user => $win_user, mx_client_host => $mx_client_host );
    $command .= " /sessionid:$session_id";
}
else {
    $session_id = 0;
}

$logger->debug("session id is $session_id");
$ENV{MXID} = $session_id;

$command =~ s/__MXID__/$session_id/g;

#
# execute the command
#
my $process;
unless ( $process = Mx::Process->background_run( command => $command, directory => $directory, logger => $logger, config => $config ) ) {
    $db_audit->decrement_session_count( win_user => $win_user, mx_scripttype => $mx_scripttype, hostname => $hostname );
#    $resourcepool->release;
    $audit->end("cannot launch a session: $Mx::Process::errstr", 1);
}

$process->mx_sessionid( $session_id );

my $dtraced_library = $config->retrieve("DTRACED_LIBRARY", 1);

my $collect_dtrace  = ( $dtraced_library && ! $mx_noaudit && $mx_scriptname && $ENV{MXDEBUG} ) ? 1 : 0;
$collect_dtrace  = ( $mx_nick =~ /DEBUG$/ ) ? 1 : $collect_dtrace;
my $collect_memory  = ( $mx_nick =~ /DEBUG$/ ) ? 1 : 0;
#my $collect_sybase  = ( $mx_nick =~ /DEBUG$/ ) ? 1 : 0;
my $collect_sybase  = 0;

my $poll_interval   = $config->CPU_SECONDS_POLL_INTERVAL;
my $max_cpu_seconds = $config->MAX_CPU_SECONDS;
my $max_vsize       = $config->MAX_VSIZE;
my $kill_flag       = $config->GLOBAL_SESSION_KILL_FLAG;

my $pid      = $process->pid;
my $appl_srv = $hostname;

my $sybase_command; my $sybase_file;
if ( $collect_sybase ) {
    my $dsquery         = $config->retrieve('DSQUERY');
    my $db_user         = $config->retrieve('MX_TSUSER');
    my $account         = Mx::Account->new( name => $db_user, config => $config, logger => $logger );
    my $password        = $account->password();
    my $isql            = $config->retrieve('SYB_DIR') . '/' . $config->retrieve('SYB_OCS') . '/bin/isql';
    my $packetsize      = $config->retrieve('SYB_PACKETSIZE');

    $sybase_file        = "${directory}/mxsybase_${mx_pid}_${appl_srv}_${pid}.log";
    $sybase_command     = "$isql -A$packetsize -b -S$dsquery -U$db_user -P$password <<EOF
exec sp__single_stat '$hostname', '$pid'
go
EOF";
}

my $memory_command; my $memory_file;
if ( $collect_memory ) {
    $memory_file    = "${directory}/memory_${mx_pid}_${appl_srv}_${pid}.log";
    $memory_command = "memory_poll.pl $pid $poll_interval";
}

my $dtrace_command; my $dtrace_file; my $dtraced_library_inode;
if ( $collect_dtrace ) {
    $dtraced_library_inode = (stat( $dtraced_library ))[1];
    $dtrace_file           = "${directory}/mxdtrace_${mx_pid}_${appl_srv}_${pid}.log";
    my $lib = basename( $dtraced_library );
    $lib =~ s/\.so$//;

    $dtrace_command = <<EOT;
/usr/sbin/dtrace -Z -n '
    #pragma D option quiet

    pid\$target:${lib}::entry
    {
        this->fdepth = ++fdepth[probefunc];
        self->start[probefunc,this->fdepth] = timestamp;
        self->vstart[probefunc,this->fdepth] = vtimestamp;
        \@Counts[probefunc] = count();
    }

    pid\$target:${lib}::return
    /self->start[probefunc,fdepth[probefunc]]/
    {
        this->fdepth = fdepth[probefunc];
        this->elapsed = timestamp - self->start[probefunc,this->fdepth];
        self->start[probefunc,this->fdepth] = 0;
        this->cpu = vtimestamp - self->vstart[probefunc,this->fdepth];
        self->vstart[probefunc,this->fdepth] = 0;
        \@Elapsed[probefunc] = sum(this->elapsed);
        \@CPU[probefunc] = sum(this->cpu);
    }

    profile:::profile-1001hz
    /pid == \$target && tid == 1/
    {
        \@Counts2[arg1] = count();
    } 

    dtrace:::END
    {
        trunc(\@Counts2, 100);
        printa("A:%s:%\@d\\n",\@Counts);
        printa("B:%s:%\@d\\n",\@CPU);
        printa("C:%s:%\@d\\n",\@Elapsed);
        printa("D:%A:%\@d\\n",\@Counts2);
    }
' '-p $pid'
EOT
}

$db_audit->update_session_pid( pid => $pid, session_id => $session_id );

my $memory_process = Mx::Process->background_run( command => $memory_command, directory => $directory, output => $memory_file, logger => $logger, config => $config ) if $collect_memory;
my $sybase_process = Mx::Process->background_run( command => $sybase_command, directory => $directory, output => $sybase_file, logger => $logger, config => $config ) if $collect_sybase;
my $dtrace_process;
if ( $collect_dtrace ) {
    my $retries = 0;
    while( ! glob("/proc/$pid/object/*.$dtraced_library_inode") && $retries < 60 ) {
        sleep 1;
        $retries++;
    }
    if ( $retries == 60 ) {
        $logger->warn("library $dtraced_library apparently still not loaded");
    }
    $dtrace_process = Mx::Process->background_run( command => $dtrace_command, directory => $directory, output => $dtrace_file, logger => $logger, config => $config, quiet => 1 );
}

$logger->debug("waiting for process $pid to finish");

$process->analyze_cmdline();

my $scannerlog = Mx::Datamart::Scannerlog->new( parent => $process, db_audit => $db_audit, logger => $logger, config => $config );

my $mmslog    = $directory . '/logs/mmslogs/' . $pid . '/journal.txt';
my $mmstarget = $config->MMSDIR . '/' . $session_id . '.txt';
my $mmssize   = 0;

my $resourcepool_acquired = 0; my $cpu_seconds = 0; my $cpu_seconds_alerted = 0; my $vsize = 0; my $vsize_alerted = 0; my $semaphore; my $recorded_start_delay = 0;
my $sleep_time = 0;
while ( waitpid( $pid, &WNOHANG ) != $pid ) {
    if ( $sleep_time++ < $poll_interval ) {
        sleep(1);
        next;
    }

    $sleep_time = 0;

#    if ( $mx_scripttype eq 'scanner' && ! $resourcepool_acquired ) {
#        my ( $mx_scripttype2, $mx_scriptname2, $entity2, $runtype2 ) = $db_audit->retrieve_session2( id => $session_id );
#        if ( $mx_scriptname2 ) {
#            $resourcepool->acquire( mx_scripttype => $mx_scripttype2, mx_scriptname => $mx_scriptname2, entity => $entity2, runtype => $runtype2 );
#            $resourcepool_acquired = 1;
#        } 
#    }

    unless ( $mx_noaudit ) {
        my $current_vsize;
        ( $cpu_seconds, $current_vsize ) = Mx::Process->cpu_seconds_and_vsize( $pid );
        $vsize = $current_vsize if $current_vsize > $vsize;
    }

    #
    # send an alert if the number of cpu seconds is too high
    #
    if ( $cpu_seconds && $cpu_seconds > $max_cpu_seconds && $win_user && ! $cpu_seconds_alerted ) {
        my $alert = Mx::Alert->new( name => 'enduser_cpu_seconds', config => $config, logger => $logger );
        $alert->trigger( level => $Mx::Alert::LEVEL_WARNING, item => $win_user, values => [ $win_user, $cpu_seconds, $session_id ] );
        $cpu_seconds_alerted = 1;
    }

    #
    # send an alert if the virtual memory size is > threshold
    #
    if ( $vsize && $vsize > $max_vsize && ! $vsize_alerted ) {
        my $alert = Mx::Alert->new( name => 'session_vsize', config => $config, logger => $logger );
        $alert->trigger( level => $Mx::Alert::LEVEL_WARNING, item => $session_id, values => [ $win_user, $session_id ] );
        $vsize_alerted = 1;
        if ( $win_user && $config->PILLAR ne 'P' ) {
            my $message = Mx::Message->new(
              destination => $ENV{MXENV},
              message     => "Your session with NPID $pid is consuming 3GB of memory. Bumpy road ahead.",
              priority    => $Mx::Message::PRIO_HIGH,
              db_audit    => $db_audit,
              config      => $config,
              logger      => $logger
            );

            $message->send;
        }
    }

    #
    # check if the global kill flag is present
    #
    if ( -f $kill_flag && $mx_nick ne 'SMCOBJECTREPOSITORY.ENGINE' ) {
        $logger->warn("global kill flag detected ($kill_flag), killing session");
        $process->kill( db_audit => $db_audit );
    }

    unless ( $mx_noaudit || $recorded_start_delay ) {
        if ( $command =~ /\s+\/TIMER\s+/ ) {
            my @files = glob("${directory}/mxtiming_${mx_pid}_${appl_srv}_*.log");
            if ( scalar(@files) == 1 ) {
                my $timingfile = shift @files;
                if ( my $start_delay = $db_audit->record_start_delay( file => $timingfile, session_id => $session_id ) ) {
                    $recorded_start_delay = 1;
                    $logger->debug("start delay recorded: $start_delay seconds");
                }
            }
        }
    }

    #
    # try to determine the mx login
    #
    unless ( $mx_user ) {
        my %session_map = Mx::Process->session_map( logger => $logger, config => $config );
        my $mx_login = $session_map{"$pid:$hostname"} || $session_map{"$pid:_"};
        if ( $mx_login ) {
            $mx_user  = $mx_login->{user};
            $mx_group = $mx_login->{group};
            $logger->info("login identified, user $mx_user, group $mx_group");
            #
            # check for a single session user
            #
            if ( grep /^$mx_user$/, @single_session_users ) {
                $logger->info("$mx_user is a single session user");
                $semaphore = Mx::Semaphore->new( key => $mx_user, create => 1, logger => $logger, config => $config );
                if ( $semaphore->acquire( non_blocking => 1 ) == -1 ) {
                    $logger->error("already a session with user $mx_user, killing this one");
                    if ( $win_user ) {
                        my $message = Mx::Message->new(
                          destination => $ENV{MXENV},
                          message     => "A session with login '$mx_user' already exists",
                          priority    => $Mx::Message::PRIO_HIGH,
                          db_audit    => $db_audit,
                          config      => $config,
                          logger      => $logger
                        );

                        $message->send;
                    }
                    $process->kill( db_audit => $db_audit );
                }
            }
            #
            # check for allowed groups
            #
            if ( @allowed_groups ) {
                unless ( grep /^$mx_group$/, @allowed_groups ) {
                    $logger->error("group $mx_group does not belong to the list of allowed groups for nick $mx_nick");
                    if ( $win_user ) {
                        my $message = Mx::Message->new(
                          destination => $ENV{MXENV},
                          message     => "Group $mx_group does not belong to the list of allowed groups for nick $mx_nick",
                          priority    => $Mx::Message::PRIO_HIGH,
                          db_audit    => $db_audit,
                          config      => $config,
                          logger      => $logger
                        );

                        $message->send;
                    }
                    $process->kill( db_audit => $db_audit );
                }
            }
        }
    }

    $scannerlog->check() if $scannerlog;

    if ( -f $mmslog ) {
        my $mtime = (stat( $mmslog ))[10];

        if ( $mtime > $mx_starttime ) {
            my $current_size = -s $mmslog;
            if ( $current_size > $mmssize ) {
                if ( copy $mmslog, $mmstarget ) {
                    $mmssize = $current_size;
                }
                else {
                    $logger->error("cannot copy $mmslog to $mmstarget: $!");
                }
            }
        }
    }
}

my $exitcode = $? >> 8;
$logger->debug("process $pid finished (exitcode $exitcode)");

$db_audit->decrement_session_count( win_user => $win_user, mx_scripttype => $mx_scripttype, hostname => $hostname );

#$resourcepool->release;

$semaphore->release() if $semaphore;

#
# check if a corefile was generated
#
my $corefile = $config->retrieve("CRASHDIR") . '/mx.' . $appl_srv . '.' . $pid . '.core';
if ( -e $corefile ) {
    my ( $core_path, $pstack_path, $pmap_path, $size, $timestamp, $function ) = Mx::Process->analyze_corefile( file => $corefile, id => $session_id, logger => $logger, config => $config );
    $corefile = $core_path;

    my $keep_cores        = $config->KEEP_CORES;
    my $stored_core_path  = ( $keep_cores && $function ) ? $core_path : undef;

    my $core_id = $db_audit->record_core(
      session_id  => $session_id,
      pstack_path => $pstack_path,
      pmap_path   => $pmap_path,
      core_path   => $stored_core_path,
      hostname    => $hostname,
      size        => $size,
      timestamp   => $timestamp,
      win_user    => $win_user,
      mx_user     => $mx_user, 
      mx_group    => $mx_group,
      mx_nick     => $mx_nick,
      function    => $function
    );

    if ( ! $stored_core_path ) {
        unless ( unlink $core_path ) {
            $logger->error("unable to delete $core_path: $!");
        }
    }
    elsif ( my $record = $db_audit->retrieve_similar_core( id => $core_id, function => $function, hostname => $hostname ) ) {
        my $id        = $record->[0];
        my $core_path = $record->[4];

        if ( unlink $core_path ) {
            $db_audit->update_core( id => $id );
        }
        else {
            $logger->error("unable to delete $core_path: $!");
        }
    }
     
    my $alert = Mx::Alert->new( name => 'session_core', config => $config, logger => $logger );
    $alert->trigger( level => $Mx::Alert::LEVEL_WARNING, values => [ $session_id, $core_path ] );

    $exitcode = $Mx::Error::CORE_DUMPED;
}
else {
    $corefile = undef;
}

unless ( $mx_noaudit ) {
    my $user  = $app_user  || $mx_user;
    my $group = $app_group || $mx_group;
    $db_audit->record_session_mx_end( session_id => $session_id, exitcode => $exitcode, pid => $pid, corefile => $corefile, mx_user => $user, mx_group => $group, cpu_seconds => $cpu_seconds, vsize => $vsize );
}

$memory_process->kill() if $collect_memory;
$sybase_process->kill() if $collect_sybase;

if ( $command =~ /\s+\/TIMER\s+/ ) {
    $logger->debug('collecting timing information');
    my @files = glob("${directory}/mxtiming_${mx_pid}_${appl_srv}_*.log");
    if ( scalar(@files) == 1 ) {
        my $timingfile = shift @files;
        $db_audit->collect_timings( file => $timingfile, session_id => $session_id ) if $session_id;
        unlink( $timingfile );
    }
    else {
        $logger->error("found no or more than one timing file: @files");
    }
}

my $sqltrace_file = $config->retrieve("%SESSIONS%$mx_nick%stats_path") . "/${session_id}.${pid}.trc";
if ( $command =~ /\s+\/RDBMS_STATISTICS:/ ) {
    $logger->debug('collecting sqltrace information');
    if ( $db_audit->collect_sqltrace( file => $sqltrace_file, session_id => $session_id ) ) {
        unlink( $sqltrace_file );
    }
}

if ( $command =~ /\s+\/RDBMS_STATISTICS:\S+:2/ ) {
    $logger->debug('collecting sqlio information');
    $db_audit->collect_sqlio( session_id => $session_id );
}

if ( $collect_memory ) {
    $logger->debug('collecting memory information');
    if ( $db_audit->collect_memory( file => $memory_file, session_id => $session_id ) ) {
        unlink( $memory_file );
    }
}

if ( $collect_sybase ) {
    $logger->debug('collecting sybase information');
    if ( $db_audit->collect_sybase( file => $sybase_file, session_id => $session_id ) ) {
        unlink( $sybase_file );
    }
}

if ( $collect_dtrace && $mx_nick =~ /DEBUG$/ ) {
    $logger->debug('collecting dtrace information');
    if ( my $nr_queries = $db_audit->collect_dtrace( file => $dtrace_file, session_id => $session_id, library => basename( $dtraced_library ) ) ) {
        $db_audit->update_session_nr_queries( session_id => $session_id, nr_queries => $nr_queries );
    }
    unlink( $dtrace_file );
}

$scannerlog->check() if $scannerlog;

$db_audit->close();

unless ( $mx_noaudit ) {
    if ( $mx_scriptname ) {
        $audit->end("scripttype $mx_scripttype, scriptname $mx_scriptname, nick $mx_nick, mx_pid $mx_pid", $exitcode);
    }
    elsif ( $win_user ) {
        $audit->end("nick $mx_nick, user $win_user, host $mx_client_host, ip $mx_client_ip, mx_pid $mx_pid", $exitcode);
    }
    else {
        $audit->end("nick $mx_nick, mx_pid $mx_pid", $exitcode);
    }
}

#----------#
sub ignore {
#----------#
    my ( $sig ) = @_;

    $logger->warn("wrapper for session $session_id received signal $sig");
}
