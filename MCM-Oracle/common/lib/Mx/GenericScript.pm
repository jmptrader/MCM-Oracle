package Mx::GenericScript;

use strict;

use Carp;
use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Error;
use Mx::Account;
use Mx::Process;
use Mx::Mail;
use Mx::Util;
use Mx::DBaudit;
use Mx::Report;
use Mx::Filter;
use Mx::Scheduler;
use Mx::Murex;
use Mx::Alert;
use Mx::Datamart::Feeder;
use Mx::Datamart::Feedertable;
use Mx::ProcScriptXML;
use IO::File;
use XML::XPath;
use File::Basename;
use File::Temp;
use File::Copy;

use constant SCRIPTSHELL => 1;
use constant SCRIPT      => 2;
use constant BATCH       => 3;
use constant MACRO       => 4;
use constant MONITOR     => 5;
use constant ANT         => 6;
use constant DM_BATCH    => 7;
use constant ORCHEST_ANT => 8;

use constant INITIALIZED => 1;
use constant RUNNING     => 2;
use constant FINISHED    => 3;
use constant FAILED      => 4;

use constant MXJ_SCRIPT_FAMILY     => 'Generic';
use constant MXJ_SCRIPT_QUERY      => 'applyXmlAction';
use constant DEFAULT_DEBUG_LEVEL   => 2;

my %MXJ_JAR_FILE = (
    1 => 'murex.download.guiclient.download',
    2 => 'murex.download.guiclient.download',
    3 => 'murex.download.guiclient.download',
    4 => 'murex.download.service.download',
    5 => 'murex.download.service.download',
    6 => 'murex.download.monit_unix.download',
    7 => 'murex.download.guiclient.download',
    8 => 'murex.download.mxclearing-orchestrator-client.download',
);

my %MXJ_CLASS_NAME = (
    1 => 'murex.apps.middleware.client.home.script.XmlRequestScriptShell',
    2 => 'murex.apps.middleware.client.home.script.XmlRequestScript',
    3 => 'murex.apps.middleware.client.home.script.XmlRequestScriptShell',
    4 => 'murex.gui.api.ScriptReader',
    5 => 'murex.apps.middleware.client.monitor.script.Monitor',
    6 => 'murex.apps.middleware.client.ant.ScriptAnt',
    7 => 'murex.apps.middleware.client.home.script.XmlRequestScriptShell',
    8 => 'murex.apps.middleware.client.ant.ScriptAnt',
);

my %MXJ_NICK_NAME = (
    1 => 'MXPROCESSINGSCRIPT',
    2 => 'MXPROCESSINGSCRIPT',
    3 => 'MXPROCESSINGSCRIPT',
    4 => 'MX',
    5 => 'MX',
    6 => 'MX',
    7 => 'MXPROCESSINGSCRIPT',
    8 => 'MX',
);

my %MXJ_IDENTIFIER = (
    1  => 'scriptshell',
    2  => 'script',
    3  => 'batch',
    4  => 'macro',
    5  => 'monitor',
    6  => 'ant',
    7  => 'dm_batch',
    8  => 'orchest ant',
    9  => 'scanner',
    10 => 'user session',
);

our $errstr = undef;


#
# Attributes:
#
# name:            name of the script/batch/macro/monitor
# nick:            MX nickname
# headerfile:      XML script header
# answerfile:      XML answer file
# logfile:         XML logfile
# files:           labels of the files that will be produced in case of a batch
# tables:          labels of the tables that will be produced in case of a batch
# reports:         list of all the reports produced by a batch
# account:         a Mx::Account object which contains the username, password, group and desk
# logdir:          directory used for all the input and output files
# start_time       start time
# start_date       start date
# end_time         end time
# sched_jobstream  jobstream name in the scheduler
# req_process      Mx::Process which corresponds to the request command
# mx_process       Mx::Process which corresponds to the actual mx process
# id               unique identifier which links req_process and mx_process
# config:          a Mx::Config instance
# logger           a Mx::Logger instance
# status           see the defined constants above
# exitcode         exitcode of the last run
# db_audit         a database connection for auditing
#

#
# Arguments:
#
# name:            name of the script/batch/macro/monitor/ant script
# nick:            nick to be used
# type:            is it a script or a batch or a macro or a monitor or a ant script
# template:        XML template file
# target:          target in case of an ant script
# cfgfile:         values for the placeholders in the template
# cfghash:         values for the placeholders in the template
# account:         a Mx::Account instance
# sched_jobstream: jobstream name in the scheduler (optional)
# project:         name of the project to which the script belongs
# logger:          a Mx::Logger instance
# config:          a Mx::Config instance
# entity:          Full Murex entity name
# runtype:         O, 1, X, V or N
# mds:             marketdata set
# extra:           extra arguments which should be passed to Murex
# no_audit:        the session will not be recorded in the monitoring DB if set to true (do not use for real MX sessions!!!)
# no_extra_logdir: do not create separate logdirs for this run
# ignore_warnings: in case of 'SCRIPT' type logfile analysis, ignore warnings
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;

    #
    # check logger argument
    #
    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $errstr = 'missing argument in initialisation of Murex script (config)';
        $logger->error($errstr);
        return;
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $errstr = 'config argument is not of type Mx::Config';
        $logger->error($errstr);
        return;
    }
    $self->{config} = $config;

    #
    # check type argument
    #
    my $type = $args{type};
    unless ( $type == SCRIPTSHELL or $type == SCRIPT or $type == BATCH or $type == MACRO or $type == MONITOR or $type == ANT or $type == ORCHEST_ANT or $type == DM_BATCH  ) {
        $errstr = "wrong or missing type ($type)";
        $logger->error($errstr);
        return;
    }
    $self->{type} = $type;

    #
    # set the market data set 
    #
    $self->{mds} = $args{mds} || $config->retrieve('MDS_DEFAULT');

    $self->{entity}  = $args{entity};
    $self->{runtype} = $args{runtype};

    #
    # check nick argument
    #
    $self->{nick} = $args{nick} || $MXJ_NICK_NAME{$type};

    #
    # check portfolio argument (optional)
    #
    if ( $args{portfolio} ) {
        $self->{portfolio} = $args{portfolio};
    }

    #
    # check target argument (optional)
    #
    if ( $args{target} ) {
        $self->{ant_target} = $args{target};
    }

    #
    # check account argument
    #
    if ( $type == SCRIPTSHELL or $type == BATCH or $type == DM_BATCH ) {
        if ( my $account = $args{account} ) {
            unless ( ref($account) eq 'Mx::Account' ) {
                $errstr = 'account argument is not of type Mx::Account';
                $logger->error($errstr);
                return;
            }
            $self->{account} = $account;
        }
    }

    #
    # check name argument
    #
    my $name;
    unless ( $name = $args{name} ) {
        $errstr = 'missing argument in initialisation of Murex script (name)';
        $logger->error($errstr);
        return;
    }
    #
    # substitute spaces by underscores to avoid problems
    #
    $name =~ s/\s+/_/g;
    $self->{name} = $name;

    #
    # if it's a batch
    #
    if ( $type == BATCH or $type == MACRO or $type == DM_BATCH ) {
        $self->{oracle}  = $args{oracle};
        $self->{library} = $args{library};
    }
    if ( $type == DM_BATCH ) {
        $self->{oracle_rep} = $args{oracle_rep};
    }
    if ( $type == BATCH ) {
        $self->{reports} = [];
    }

    #
    # check if this is an autobalance batch
    #
    $self->{ab_session_id} = $args{ab_session_id} || 0;

    #
    # define and create the log directory
    #
    my $logdir;
    unless ( $logdir = _logdir( $name, $config->LOGDIR, $args{no_extra_logdir}, $self->{ab_session_id} ) ) {
        $logger->error($errstr);
        return;
    }
    else {
        $logger->info("using $logdir as log directory");
    }
    $self->{logdir} = $logdir;

    #
    # check template argument
    #
    my $template;
    unless ( $template = $args{template} ) {
        $errstr = 'missing argument in initialisation of Murex script (template)';
        $logger->error($errstr);
        return;
    }
    $self->{template} = $template;
    $self->{answerfile} = $self->{logdir} . '/answer.xml';
    $self->{logfile}    = $self->{logdir} . '/log.xml';
    $self->{headerfile} = $self->{logdir} . '/ps.xml';
    $self->{cfgfile}    = $args{cfgfile};
    $self->{cfghash}    = $args{cfghash};

    #
    # extra arguments which should be passed unaltered to Murex
    #
    if ( $args{extra} ) {
        $self->{extra_args} = ' ' . $args{extra};
    }
    else {
        $self->{extra_args} = '';
    }
    if ( $args{jopt} ) {
        $self->{jopt} = ' ' . $args{jopt};
    }
    else {
        $self->{jopt} = '';
    }

    #
    # Scheduler details  
    #
    $self->{sched_jobstream} = $args{sched_jobstream};
    $self->{project}         = $args{project};
    $self->{remote_delay}    = $args{remote_delay};

    $self->{no_audit}        = $args{no_audit};
    $self->{ignore_warnings} = $args{ignore_warnings};

    $self->{status} = INITIALIZED;

    bless $self, $class;
}

#
# Arguments:
#
# exclusive:    boolean indicating that this script cannot be run in parallel
# debug:        boolean to switch on/off debugging 
# background:   boolean to indicate that the batch should be run in the background
#
#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $config    = $self->{config};
    my $type      = $self->{type};
    my $account   = $self->{account};

    if ( $self->{norun} ) {
        $args{exclusive}  = 0;
        $self->{no_audit} = 1;
    }
    else {
        unless ( _process_xmltemplate( $self, $self->{template}, $self->{cfgfile}, $self->{cfghash} ) ) {
            return;
        }
    }

    my $unit_args = '';
    if ( $type == SCRIPTSHELL or $type == DM_BATCH ) {
        if ( my $psx = Mx::ProcScriptXML->new( xml => $self->{headerfile}, logger => $logger ) ) {
            if ( my $unit = $psx->item_unit ) {
                if ( $psx->is_scanner_unit( $unit ) ) {
                    $unit_args = ' /scanner';
                }
            }
        }
    }

    my $db_audit  = Mx::DBaudit->new( config => $config, logger => $logger );
    $self->{db_audit} = $db_audit;

    #
    # determine the workdirectory from where the command must be launched
    #
    my $directory;
#    if ( $type == SCRIPT ) {
    if ( 0 ) {
        #
        # if the script is of type 'SCRIPT', we change to the directory where the xml-file is located as it might include
        # other xml-files in that same directory
        #
        if ( substr( $self->{template}, 0, 1 ) eq '/' ) {
            $directory = dirname( $self->{template} );
        }
        else {
            $directory = $ENV{MXCOMMON} . '/' . $ENV{MXVERSION} . '/xml';
        }
    }
    else {
        $directory  = $config->MXENV_ROOT;
    }

    #
    # if debugging is enabled...
    #
    if ( $args{debug} ) {
        $self->{nick} .= 'DEBUG';
    }

    #
    # who runs the script
    #
    my $who_args = '';
    if ( $account ) {
        $who_args =  
          ' /USER:'     . $account->name .
          ' /PASSWORD:' . $account->murex_password .
          ' /GROUP:'    . $account->group
        ;
        ( $who_args .= ' /DESK:' . $account->desk ) if $account->desk;
    }

    #
    # what needs to be executed 
    #
    my $what_args = '';
    if ( $type == SCRIPTSHELL or $type == BATCH or $type == DM_BATCH ) {
        $what_args =
          ' /MXJ_SCRIPT_HEADER:' . $self->{headerfile} .
          ' /MXJ_SCRIPT_FAMILY:' . MXJ_SCRIPT_FAMILY .
          ' /MXJ_SCRIPT_QUERY:'  . MXJ_SCRIPT_QUERY
        ;
    }
    elsif ( $type == SCRIPT or $type == MONITOR ) {
        $what_args =
          ' /MXJ_CONFIG_FILE:' . $self->{headerfile}
        ;
    }
    elsif ( $type == MACRO ) {
        $what_args =
          ' /MXJ_SCRIPT_READ_FROM:' . $self->{headerfile}
        ;
    }
    elsif ( $type == ANT or $type == ORCHEST_ANT ) {
        $what_args =
          ' /MXJ_ANT_BUILD_FILE:' . $self->{headerfile} .
          ' /MXJ_ANT_TARGET:'     . $self->{ant_target}
        ;
    }

    #
    # logging which is produced
    #
    my $answer_args = '';
    unless ( $type == MACRO or $type == MONITOR or $type == SCRIPT or $type == ANT or $type == ORCHEST_ANT ) {
        $answer_args =
          ' /MXJ_SCRIPT_ANSWER:' . $self->{answerfile} .
          ' /MXJ_SCRIPT_LOG:'    . $self->{logfile}
        ;
    }

    my $extra_java_switch = ( $type == MACRO ) ? ' -Djava.awt.headless=true' : '';

    #
    # insert an identifier in the command to identify the process
    #
    my $identifier = ' /scripttype:' . $MXJ_IDENTIFIER{$type} . ' /scriptname:' . $self->{name} . ' /entity:' . $self->{entity} . ' /runtype:' . $self->{runtype} . ' /sessionid:__SESSIONID__';

    #
    # indicate is auditing is disabled to mxsession.pl
    #
    my $audit_flag = ( $self->{no_audit} ) ? ' /noaudit' : '';

    #
    # build the command
    #
    my $mxj_class_name = $MXJ_CLASS_NAME{$type}; 
    my $classpath = $config->MXENV_ROOT . '/mxjboot.jar';
    my $command =
       $config->JAVA_HOME . '/bin/java -Xmx512M' .
      $self->{jopt} .
      ' -cp ' . $classpath .
      ' -Djava.security.policy=java.policy' .
      ' -Djava.rmi.server.codebase=http://' . $config->MXJ_FILESERVER_HOST . ':' . $config->MXJ_FILESERVER_PORT . '/' . $MXJ_JAR_FILE{$type} .
      $extra_java_switch .
      ' murex.rmi.loader.RmiLoader' .
      ' /MXJ_CLASS_NAME:'        . $mxj_class_name .
      ' /MXJ_SITE_NAME:'         . $config->MXJ_SITE_NAME .
      ' /MXJ_PLATFORM_NAME:'     . $config->MXJ_PLATFORM_NAME .
      ' /MXJ_PROCESS_NICK_NAME:' . $self->{nick} .
      $what_args .
      $answer_args .
      $identifier .
      $audit_flag .
      $who_args .
      $self->{extra_args}
    ;

    my $hostname = Mx::Util->hostname();

    $self->{id} = 0;
    $self->{id} = $db_audit->record_session_req_start( cmdline => $command, hostname => $hostname, mx_scripttype => $MXJ_IDENTIFIER{$type}, mx_scriptname => $self->{name}, mx_nick => $self->{nick}, ab_session_id => $self->{ab_session_id}, sched_jobstream => $self->{sched_jobstream}, entity => $self->{entity}, runtype => $self->{runtype}, project => $self->{project}, remote_delay => $self->{remote_delay} ) unless $self->{no_audit};
    $command =~ s/__SESSIONID__/$self->{id}/; 

    #
    # create a pidfile if the script should not be run in parallel with itself
    # 
    my $descriptor = $self->{name};
    if ( $self->{entity} ) {
        $descriptor .= '_' . $self->{entity};
    }
    if ( $self->{runtype} ) {
        $descriptor .= '_' . $self->{runtype};
    }
    $self->{req_process} = Mx::Process->new( descriptor => $descriptor, logger => $self->{logger}, config => $config );
    if ( $args{exclusive} ) {
        if ( $args{retry_interval} ) {
            until ( $self->{req_process}->set_pidfile($0, $args{pidfile} ) ) {
                sleep $args{retry_interval};
            }
        }
        else {
            unless ( $self->{req_process}->set_pidfile($0, $args{pidfile} ) ) {
                $errstr = 'not running exclusively';
                $self->{status}   = FAILED;
                $self->{exitcode} = $Mx::Error::NOT_RUNNING_EXCLUSIVELY;
                $db_audit->record_session_req_end( session_id => $self->{id}, exitcode => $Mx::Error::NOT_RUNNING_EXCLUSIVELY ) unless $self->{no_audit};
                $db_audit->close();
                return;
            }
        }
    }

    my ( $reportname, $dyn_sem ) = $self->setup_reports() if $type == BATCH;

    if ( $type == DM_BATCH ) {
        unless ( $self->setup_dm_batch() ) {
            $unit_args = '';
        }
    }

    $command .= $unit_args;

    return 0 if $self->{norun};

    $self->{status}     = RUNNING;
    $self->{start_time} = time();
    $self->{start_date} = Mx::Murex->calendardate();

    if ( $args{background} ) {
        return $self->{req_process} = Mx::Process->background_run(command => $command, directory => $directory, config => $config, logger => $logger, output => $logger->filename() );
    }


    my ( $exitcode, $runtime, $cputime, $iotime, $starttime, $batch_delay );
    my $reruns = 0;
    while ( $reruns <= 1 ) {
        my ($success, $error_message, $output);
        ($success, $error_message, $output) = Mx::Process->run( command => $command, no_output => $args{no_output}, directory => $directory, config => $config, logger => $logger );

        $self->{end_time} = time();
        $self->{output} = $output;

        if ( $self->{no_audit} or $type == MONITOR or $type == SCRIPT or $type == ANT or $type == ORCHEST_ANT ) {
            $exitcode = ( $success ) ? 0 : 1;
        }
        else {
            #
            # Get the exitcode out of the database
            #
            ( $exitcode, my $req_starttime, my $mx_starttime ) = $db_audit->get_exitcode( session_id => $self->{id} );

            unless ( defined $exitcode ) {
                if ( $output =~ /Stale NFS file handle/ ) {
                    $logger->warn("NFS stale filehandle");
                    $exitcode = $Mx::Error::NFS_STALE_FILEHANDLE;
                    last if $reruns >= 1;
                    $logger->warn("Going for a rerun");
                    $reruns++;
                    $db_audit->update_session_reruns( reruns => $reruns, session_id => $self->{id} );
                    next;
                }
                $exitcode = 666;
            }

            $batch_delay = $mx_starttime - $req_starttime;
        }

        #
        # analyze the answerfile
        #
        if ( $self->{answerfile} && -f $self->{answerfile} ) {
            my $ok; my $failure_type;
            ( $ok, $runtime, $cputime, $iotime, $starttime, $failure_type ) = _analyze_answerfile( $self->{answerfile}, $logger );
            #
            # sometimes the exitcode is 0 and yet there are errors in the answerfile
            #
            if ( $ok ) {
                $logger->debug('no errors found in the answerfile');
                $exitcode = 0;
            }
            elsif ( $failure_type eq 'service_failure' ) {
                $logger->warn("Service failure detected");
                $exitcode = $Mx::Error::MX_SERVICE_FAILURE;
                last if $reruns >= 1;
                my $runtime = $self->{end_time} - $self->{start_time};
                if ( $runtime < 300 ) {
                    $logger->warn("runtime is $runtime seconds, going for a rerun");
                    $reruns++;
                    $db_audit->update_session_reruns( reruns => $reruns, session_id => $self->{id} );
                    next;
                }
            }
            elsif ( $failure_type eq 'sybase_timeout' ) {
                $logger->warn("Sybase connect timeout detected");
                $exitcode = $Mx::Error::SYBASE_CONNECT_TIMEOUT;
                last if $reruns >= 1;
                my $runtime = $self->{end_time} - $self->{start_time};
                if ( $runtime < 600 ) {
                    $logger->warn("runtime is $runtime seconds, going for a rerun");
                    $reruns++;
                    $db_audit->update_session_reruns( reruns => $reruns, session_id => $self->{id} );
                    next;
                }
            }
            elsif ( $failure_type eq 'dyntable_overflow' ) {
                $logger->error('dynamic table overflow detected');
                $exitcode = $Mx::Error::DYNTABLE_OVERFLOW;
            }
            else {
                my $identified = 0;
                if ( $self->{logfile} && -f $self->{logfile} ) {
                    if ( my $error = _analyze_logfile2( $self->{logfile}, $logger ) ) {
                        if ( $error =~ /Unable to acquire lock/ ) {
                            $exitcode = $Mx::Error::REFDATA_LOCKED;
                            $identified = 1;
                        }
                    }
                }
                unless ( $identified ) {
                    $logger->error('answerfile reports failure');
                    $exitcode = $Mx::Error::MX_ANSWERFILE_FAILURE unless $exitcode;
                }
            }
        }
        else {
            $logger->warn('no answerfile (', $self->{answerfile}, ') found') unless $type == MACRO or $type == MONITOR or $type == ANT or $type == ORCHEST_ANT;
        }

        #
        # check the output if it's a macro
        #
        if ( $type == MACRO ) {
            if ( $output =~ /Script playback failed/ ) {
                $logger->error('macro output reports failure');
                $exitcode = $Mx::Error::MX_MACRO_FAILURE unless $exitcode;
            }
        }

        last;
    }

    $dyn_sem->release() if $dyn_sem;

    #
    # analyze the logfile
    #
    if ( $type == SCRIPT && $self->{logfile} && -f $self->{logfile} ) {
        my $ok = _analyze_logfile( $self->{logfile}, $self->{ignore_warnings}, $logger );
        unless ( $ok ) {
            $logger->error('logfile reports failure');
            $exitcode = $Mx::Error::MX_LOGFILE_FAILURE unless $exitcode;
        }
    }

    #
    # check if the necessary reports were generated
    #
    foreach my $report ( @{$self->{reports}} ) {
        unless ( $report->finish( oracle => $self->{oracle} ) ) {
            $exitcode = $Mx::Error::MISSING_REPORT unless $exitcode;
        }
    }

    if ( $type == BATCH && $exitcode == $Mx::Error::MISSING_REPORT ) {
        my $query;
        unless ( $query = $self->{library}->query('repfile_dyntable_check') ) {
            $logger->logdie("query with as key 'repfile_dyntable_check' cannot be retrieved from the library");
        }

        my $result;
        unless ( $result = $self->{oracle}->query( query => $query, values => [ $reportname ] ) ) {
            $logger->logdie("cannot retrieve report '$reportname'");
        }
   
        my $file; my $table; 
        unless ( ($file, $table) = $result->next ) {
            $logger->logdie("cannot find report '$reportname'");
        }

        $logger->error("current report definition for report $reportname contains as report file '$file' and as dyntable '$table'");

        my $cfg_batch_delay = $config->BATCH_DELAY;
        if ( $batch_delay >= $cfg_batch_delay ) {
            $exitcode = $Mx::Error::BATCH_DELAY_EXCEEDED;
            $logger->error("measured batch delay ($batch_delay) is greater than configured batch delay ($cfg_batch_delay)");
        }
    }

    $self->finish_dm_batch() if $type == DM_BATCH;

    $self->{exitcode} = $exitcode;
    $self->{status}   = ( $exitcode ) ? FAILED : FINISHED;
    if ( $args{exclusive} ) {
        $self->{req_process}->remove_pidfile();
    }
    $db_audit->record_session_req_end( session_id => $self->{id}, exitcode => $exitcode, runtime => $runtime, cputime => $cputime, iotime => $iotime, start_delay => $starttime ) unless $self->{no_audit};

    if ( $type == BATCH ) {
        my $start_delay     = $db_audit->get_start_delay( session_id => $self->{id} );
        my $max_start_delay = $config->BATCH_DELAY;
        if ( $start_delay > $max_start_delay ) {
            my $alert = Mx::Alert->new( name => 'batch_delay', config => $config, logger => $logger );
            $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $self->{name}, $self->{project}, $start_delay ], item => $self->{name} );
        } 
    }

    $db_audit->close();
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#---------------#
sub outputfiles {
#---------------#
    my ( $self ) = @_;

    my %files = ();
    my $db_audit = Mx::DBaudit->new( config => $self->{config}, logger => $self->{logger} );
    my @report_ids = $db_audit->retrieve_linked_reports( session_id => $self->{id} );
    foreach my $id ( @report_ids ) {
        my $report = $db_audit->retrieve_report( id => $id );
        #
        # the batch might end before the mod after cmd is finished, so give the monitoring db some time to catch up
        #
        until ( $report->[6] ) {
            $self->{logger}->warn("report $id has not yet a corresponding text path in the monitoring DB - going to sleep for 5 seconds");
            sleep 5;
            $report = $db_audit->retrieve_report( id => $id );
        }
        $files{$id} = $report->[6];
    }
    $db_audit->close();
    return( %files );
}

#----------#
sub output {
#----------#
    my ( $self ) = @_;

    return $self->{output};
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#-----------#
sub runtime {
#--------------#
    my ( $self ) = @_;

    return( time() - $self->{start_time} );
}

#---------------#
sub req_process {
#---------------#
    my ( $self ) = @_;

    return $self->{req_process};
}

#--------------#
sub mx_process {
#--------------#
    my ( $self ) = @_;

    return $self->{mx_process};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;

    return $self->{status};
}

#--------#
sub kill {
#--------#
    my ( $self ) = @_;
    
    my $process = $self->{mx_process} || $self->{req_process};
    my $logger  = $self->{logger};
    my $name    = $self->{name};
    $logger->debug("killing script $name");
    if ( $process->kill() ) {
        $logger->debug("script $name killed");
        $self->{status} = FAILED;
        return 1;
    }
    else {
        $logger->error("script $name cannot be killed");
        return;
    }
}



#
# Arguments:
#
# address:  list of mail addresses to which a report must be sent
#
#--------#
sub mail {
#--------#
    my ( $self, %args ) = @_;

    my $config    = $self->{config};
    my $body      = _mailbody($self);
    my $type      = $self->{type};
    my $what      = $MXJ_IDENTIFIER{$type};
    my $subject;
    if ( $self->{status} == FINISHED ) {
        $subject = sprintf "%s: INFO: $what %s finished on %s", $config->MXENV, $self->{name}, Mx::Util->hostname;
    }
    elsif ( $self->{status} == FAILED ) {
        $subject = sprintf "%s: ALERT: $what %s failed on %s", $config->MXENV, $self->{name}, Mx::Util->hostname;
    }
    else {
        $errstr = 'can only send a mail when the status is FINISHED or FAILED';
        return;
    }
    my $logger = $self->{logger};
    my $mail = Mx::Mail->new( to => $args{address}, subject => $subject, body => $body, config => $config, logger => $logger );
    $mail->send();
    return 1;
}

#------------#
sub exitcode {
#------------#
    my ($self) = @_;

    return $self->{exitcode};
}

#----------------#
sub set_exitcode {
#----------------#
    my ( $self, $exitcode ) = @_;
 
 
    $self->{exitcode} = $exitcode;
    my $db_audit = Mx::DBaudit->new( config => $self->{config}, logger => $self->{logger} );
    $db_audit->set_session_exitcode( session_id => $self->{id}, exitcode => $exitcode );
    $db_audit->close();
}

#------------#
sub _logdir {
#------------#
    my ( $procname, $basedir, $no_extra_logdir, $ab_session_id ) = @_;


    my $date = Mx::Murex->calendardate();

    my $full_basedir = $basedir;
    $full_basedir .= "/$date";

    unless ( -d $full_basedir ) {
        unless ( mkdir( $full_basedir ) ) {
            unless ( -d $full_basedir ) {
                # might be created in the meantime
                $errstr = "cannot create $full_basedir: $!";
                return;
            }
        }

        my $symlink = $basedir . '/today';
        unlink $symlink;
        symlink $date, $symlink;
    }

    if ( $ab_session_id ) {
        $full_basedir .= '/AB_' . $ab_session_id;
        unless ( -d $full_basedir ) {
            unless ( mkdir( $full_basedir ) ) {
                $errstr = "cannot create $full_basedir: $!";
                return;
            }
        }
    }

    my $logdir = $full_basedir . '/' . $procname;

    if ( $no_extra_logdir ) {
        unless ( -d $logdir ) {
            unless ( mkdir( $logdir ) ) {
                unless ( -d $logdir ) {
                    # might be created in the meantime
                    $errstr = "cannot create $logdir: $!";
                    return;
                }
            }
        }
    }
    else { 
        my $created = 0;
        my $i = 1;
        while ( ! $created ) {
            while ( -d $logdir ) {
                $logdir = $full_basedir . '/' . $procname . '_' . $i++;
            }
            if ( mkdir( $logdir ) ) {
                $created = 1;
            }
            else {
                unless ( -d $logdir ) {
                    $errstr = "cannot create $logdir: $!";
                    return;
                }
            }
        }
    }
    return $logdir;
}


#------------------------#
sub _process_xmltemplate {
#------------------------#
    my ( $self, $template, $cfgfile, $cfghash ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my ($xmlin, $out);
    if ( $template =~ /^\s*<\?xml/ ) {
        $xmlin = $template;
    }
    else {
        my $in;
        unless ( $in = IO::File->new( $template, '<' ) ) {
            $errstr = "cannot open $template: $!";
            $logger->error($errstr);
            return;
        }
        while ( <$in> ) {
            $xmlin .= $_;
        }
        $in->close;
    }

    unless ( $out = IO::File->new( $self->{headerfile}, '>' ) ) {
        $errstr = 'cannot open ' . $self->{headerfile} . ": $!";
        $logger->error($errstr);
        return;
    }
    my %params;
    if ( $cfgfile ) {
        my $cfg;
        unless ( $cfg = IO::File->new( $cfgfile, '<' ) ) {
            $errstr = "cannot open $cfgfile: $!";
            $logger->error($errstr);
            return;
        }
        while ( my $line = <$cfg> ) {
            if ( $line =~ /^\s*(__\w+__)\s*=\s*(.+\S)\s*$/ ) {
                $params{$1} = $2;
            }
        }
        $cfg->close;
    }
    if ( $cfghash && ref($cfghash) eq 'HASH' ) {
        while ( my ($key, $value) = each %{$cfghash} ) {
            $params{$key} = $value;
        }
    }

    $params{__NAME__}       = ( $self->{batchname} ) ? $self->{batchname} : $self->{name};
    $params{__PORTFOLIO__}  = $self->{portfolio}  if $self->{portfolio};
    $params{__ANSWERFILE__} = $self->{answerfile} if $self->{answerfile};
    $params{__LOGFILE__}    = $self->{logfile}    if $self->{logfile};
    $params{__MDS__}        = $self->{mds}        if $self->{mds};
    $params{__ENTITY__}     = $self->{entity}     if $self->{entity};
    $params{__NICK__}       = $self->{nick}       if $self->{nick};

    my $previous_eom_date = $params{__PREVIOUS_EOM_DATE__};
    foreach my $line ( split "\n", $xmlin ) {
        while ( $line =~ /__(\w+):(CRYPTED)?PASSWORD__/ ) {
            my $user    = $1;
            my $crypted = $2;
            my $account;
            unless ( $account = Mx::Account->new( name => $user, config => $config, logger => $logger ) ) {
                $errstr = "cannot retrieve account $user";
                $logger->error($errstr);
            }
            my $password = ( $crypted ) ? $account->murex_password() : $account->password();
            $line =~ s/__$user:(CRYPTED)?PASSWORD__/$password/g;
        }
        while ( $line =~ /\b(__[^_]\$?\w+?[^_]__)\b/ ) {
            my $before = $`;
            my $ph     = $1;
            my $after  = $'; 
            if ( exists $params{$ph} ) {
                $line = $before . $params{$ph} . $after;
            }
            elsif ( $ph =~ /^__\$(.+)__$/ ) {
                my $cfg_param = $1;
                $line = $before . $config->retrieve( $cfg_param ) . $after;
            }
            elsif ( $ph eq '__PREVIOUS_EOM_DATE__' ) {
                my $plcc = 'PLCC_' . $self->{entity};
                $previous_eom_date = $previous_eom_date || Mx::Murex->previous_eom_date( plcc => $plcc, oracle => $self->{oracle}, library => $self->{library}, config => $config, logger => $logger );
                $line = $before . $previous_eom_date . $after;
            }
            else {
                $errstr = "no substitution found for placeholder $ph in template file $template";
                $logger->error($errstr);
                return;
            }
        }
        print $out "$line\n";
    }

    $out->close;

    return 1;
}

#
# Function to replace placeholders in a binary template file.
#
# Arguments:
# template   Full path to the template file
# cfghash    reference to a hash containing placeholders and corresponding replacement strings
# dummy      If this is set to true, no replacements will be done, only the number of placeholders found is returned
#
 
#------------------------#
sub _process_bintemplate {
#------------------------#
    my ( $self, $template, $cfghash, $dummy ) = @_;
 
 
    my $recsize = 256;

    my $logger = $self->{logger};
    my $config = $self->{config};
 
    unless ( $dummy ) {
        while ( my ( $key, $value ) = each %{$cfghash} ) {
            unless ( length($key) == length($value) ) {
                $logger->logdie("key ($key) and value ($value) do not have the same length");
            }
        }
    }
 
    unless ( open FH, "+<$template" ) {
       $logger->logdie("cannot open $template: $!");
    }
 
    my %replacements = (); my @window = (); my $record;
    while ( read( FH, $record, $recsize ) ) {
        push @window, $record;
 
        my $window = join '', @window;
 
        while ( my ( $key, $value ) = each %{$cfghash} ) {
            if ( $window =~ m/$key/ ) {
                my $position = tell(FH) - length($window) + length($`);
                $replacements{$position} = $value;
                $logger->debug("found string $key at position $position");
            }
        }
 
        if ( @window > 2 ) {
            shift @window;
        }
    }
 
    unless ( $dummy ) {
        while ( my ( $position, $value ) = each %replacements ) {
            $logger->debug("inserting string $value at position $position");
            seek( FH, $position, 0);
            print FH $value;
        }
    }
 
    close(FH);
 
    return scalar( keys %replacements );
}

#-----------------#
sub setup_reports {
#-----------------#
    my ( $self ) = @_;


    my $logger         = $self->{logger};
    my $config         = $self->{config};
    my $oracle         = $self->{oracle};
    my $db_audit       = $self->{db_audit};
    my $library        = $self->{library};
    my $batchname      = $self->{batchname};
    my $batchtemplate  = $self->{batchtemplate};
    my $entity         = $self->{entity};
    my $runtype        = $self->{runtype};
    my $mds            = $self->{mds};
    my $session_id     = $self->{id};
    my $desk           = $self->{account}->desk;

    my @files   = $self->{files}   ? @{$self->{files}}   : ();
    my @tables  = $self->{tables}  ? @{$self->{tables}}  : ();
    my @filters = $self->{filters} ? @{$self->{filters}} : ();

    my @reports = ();

    my $nr_files   = @files;
    my $nr_tables  = @tables;

    my $query; my $result;
    unless ( $query = $library->query('batch_to_report') ) {
        $logger->logdie("query with as key 'batch_to_report' cannot be retrieved from the library");
    }

    unless ( $result = $oracle->query( query => $query, values => [ $batchname ] ) ) {
        $logger->logdie("cannot retrieve batch '$batchname'");
    }

    my ($reportname, $filterlabel);
    unless ( ($reportname, $filterlabel) = $result->next ) {
        $logger->logdie("cannot find batch '$batchname'");
    }

    if ( @filters and ! $filterlabel ) {
        $logger->logdie("batch does not contain a filter, so cannot attach a new filter");
    }

    unless ( $query = $library->query('mds_ref') ) {
        $logger->logdie("query with as key 'mds_ref' cannot be retrieved from the library");
    }

    unless ( $result = $oracle->query( query => $query, values => [ $mds ] ) ) {
        $logger->logdie("cannot retrieve MDS '$mds'");
    }

    my $mds_ref;
    unless ( $mds_ref = $result->nextref->[0] ) {
        $logger->logdie("cannot find MDS '$mds'");
    }

    unless ( $query = $library->query('set_mds') ) {
        $logger->logdie("query with as key 'set_mds' cannot be retrieved from the library");
    }

    if ( $oracle->do( statement => $query, values => [ $mds_ref, $batchname ] ) ) {
        $logger->info("market data set changed to '$mds'"); 
    }
    else {
        $logger->logdie("unable to change market data set to '$mds'");
    }

    unless ( $query = $library->query('report_file_tables') ) {
        $logger->logdie("query with as key 'report_file_tables' cannot be retrieved from the library");
    }
 
    unless ( $result = $oracle->query( query => $query, values => [ $reportname ] ) ) {
        $logger->logdie("cannot retrieve report '$reportname'");
    }

    my ($report_field, $dyntable0, $dyntable1, $dyntable2, $dyntable3, $dyntable4);
    
    unless ( ($report_field, $dyntable0, $dyntable1, $dyntable2, $dyntable3, $dyntable4) = @{$result->[0]} ) {
        $logger->logdie("cannot find report '$reportname'");
    }

    my $report_template = $config->retrieve('REPORT_TEMPLATE_DIR') . '/' . $batchtemplate;
    my ( $report_extension ) = $report_template =~ /\.(\w+)\s*$/;
 
    if ( -f $report_template ) {
        $logger->debug("report template $report_template found");
    }
    else {
        $logger->logdie("report template $report_template not found");
    }
 
    my $report_template_ph = $config->retrieve('REPORT_TEMPLATE_PH');
 
    my %filehash = ();
    my @ph = ();
    my $count = 0;
    foreach ( @files ) {
        my $ph = $report_template_ph;
        my $length = -1 * length( $count );
        substr( $ph, $length) = $count;
        push @ph, $ph;
        $filehash{$ph} = undef;
        $count++;
    }

    my $dummy = 1;
    my $nr_ph = _process_bintemplate( $self, $report_template, { substr( $report_template_ph, 0, -2 ) => undef }, $dummy );
 
    if ( $nr_files == $nr_ph ) {
        $logger->debug("number of files ($nr_files) matches number of placeholders ($nr_ph)");
    }
    else {
        $logger->logdie("number of files ($nr_files) doesn't match number of placeholders ($nr_ph)");
    }

    my %tablehash = ();
    my @dyntables = ();
    foreach my $dyntable ($dyntable0, $dyntable1, $dyntable2, $dyntable3, $dyntable4) {
        next unless $dyntable;
        push @dyntables, $dyntable;
        $tablehash{$dyntable} = undef;
    }
 
    my $nr_dyntables = @dyntables;
 
    if ( $nr_tables == $nr_dyntables ) {
        $logger->debug("number of tables ($nr_tables) matches number of dyntables ($nr_dyntables)");
    }
    else {
        $logger->logdie("number of tables ($nr_tables) doesn't match number of dyntables ($nr_dyntables)");
    }

    my $report_output_dir = $config->retrieve('REPORT_OUTPUT_DIR');
 
    my $table_prefix = 'REPBATCH#';
    my $query_label;
    if ( $desk =~ /^PC_/ ) {
        $query_label   = 'pc_ref';
        $table_prefix .= 'PC_';
    }
    elsif ( $desk =~ /^PLCC_/ ) {
        $query_label   = 'plcc_ref';
        $table_prefix .= 'PL_';
    }
    else {
        $query_label   = 'fo_desk_ref';
        $table_prefix .= 'FOD_';
    }

    unless ( $query = $library->query( $query_label ) ) {
        $logger->logdie("query with as key '$query_label' cannot be retrieved from the library");
    }
 
    unless ( $result = $oracle->query( query => $query, values => [ $desk ] ) ) {
        $logger->logdie("cannot retrieve desk '$desk'");
    }

    my $desk_ref;
    unless ( $desk_ref = $result->nextref->[0] ) {
        $logger->logdie("cannot find desk '$desk'");
    }
 
    $table_prefix .= $desk_ref . '#';
    $logger->debug("table prefix is '$table_prefix'");

    Mx::Report->check_delay( template => $report_template, db_audit => $db_audit, config => $config, logger => $logger );

    foreach my $filter ( @filters ) {
        $filter->install( batch => $batchname );
    }

    my $highest_id = 0;

    foreach my $file ( @files ) {
        my ( $label, $final_path ) = split /:/, $file;
        my $report = Mx::Report->new( label => $label, type => 'file', final_path => $final_path, session_id => $session_id, batchname => $self->{name}, reportname => $reportname, entity => $entity, runtype => $runtype, mds => $mds, logger => $logger, db_audit => $db_audit );
        my $report_id = $report->start();
        $highest_id = ( $highest_id < $report_id ) ? $report_id : $highest_id;

        my $ph  = shift @ph;
        my $ph2 = $report_template_ph;
        my $length = -1 * length( $report_id );
        substr( $ph2, $length) = $report_id;
        $ph2 =~ s/x/0/g;
        $filehash{$ph} = $ph2;
        my $path = $report_output_dir . '/' . basename( $ph2 );

        $report->set_path( $path );

        push @reports, $report;
    }

    unless ( $query = $library->query('get_dyntable') ) {
        $logger->logdie("query with as key 'get_dyntable' cannot be retrieved from the library");
    }

    my $max_dyn_sem_count = $config->retrieve('DYN_SEMAPHORE_COUNT');
    my $dyn_sem_key       = basename( $report_template ) . '.' . $desk;
    my $dyn_sem           = Mx::Semaphore->new( key => $dyn_sem_key, type => $Mx::Semaphore::TYPE_COUNT, count => $max_dyn_sem_count, create => 1, logger => $logger, config => $config );
    my $dyn_sem_count     = $dyn_sem->acquire();
    my $dyn_sem_active    = $max_dyn_sem_count - $dyn_sem_count - 1;

    $logger->info("number of batches active for the same dynamic tables: $dyn_sem_active");
 
    foreach my $table ( @tables ) {
        my ( $label, $historize ) = split /:/, $table;
        $historize = ( $historize =~ /^his/i ) ? 1 : 0;
        my $report = Mx::Report->new( label => $label, type => 'table', historize => $historize, session_id => $session_id, batchname => $self->{name}, reportname => $reportname, entity => $entity, runtype => $runtype, mds => $mds, logger => $logger, db_audit => $db_audit );
        my $report_id = $report->start();
        $highest_id = ( $highest_id < $report_id ) ? $report_id : $highest_id;

        my $tablename;
        my $dyntable = shift @dyntables;

        if ( $dyn_sem_active or $historize ) {
            $tablehash{$dyntable} = $report_id;
            $tablename = $table_prefix . $report_id . '_DBF';
        }
        else {
            unless ( $result = $oracle->query( query => $query, values => [ $dyntable ] ) ) {
                $logger->logdie("cannot retrieve dyntable '$dyntable'");
            }

            my $dyntable_id;
            unless ( $dyntable_id = $result->nextref->[0] ) {
                $logger->logdie("cannot retrieve dyntable '$dyntable'");
            }

            $tablename = uc( $table_prefix . $dyntable_id . '_DBF' );

            $logger->info("keeping the tablename $dyntable_id for dyntable $dyntable");
        }

        $report->set_tablename( $tablename );

        push @reports, $report;
    }

    my $report_file = $config->retrieve('MXENV_ROOT') . '/report2/' . $highest_id . '.' . lc( $report_extension );

    unless ( copy $report_template, $report_file ) {
        $logger->logdie("cannot copy $report_template to $report_file: $!");
    }

    if ( @files ) {
        unless ( _process_bintemplate( $self, $report_file, \%filehash ) ) {
            $logger->logdie("cannot update placeholders in report file $report_file");
        }

        $logger->debug("placeholders replaced in report file $report_file");
    }
 
    unless ( $query = $library->query('set_dyntable') ) {
        $logger->logdie("query with as key 'set_dyntable' cannot be retrieved from the library");
    }

    while ( my ( $dyntable, $report_id ) = each %tablehash ) {
        if ( $report_id ) {
            my $tablename = $report_id;
            $oracle->do( statement => $query, values => [ $tablename, $dyntable ] );
            $logger->debug("table for dyntable $dyntable set to $tablename");
        }
    }

    unless ( $query = $library->query('set_repfile') ) {
        $logger->logdie("query with as key 'set_repfile' cannot be retrieved from the library");
    }

    $oracle->do( statement => $query, values => [ $highest_id . '.' . uc( $report_extension), $reportname ] );

    $self->{reports} = [ @reports ];

    return ( $reportname, $dyn_sem );
}

#------------------#
sub setup_dm_batch {
#------------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $config     = $self->{config};
    my $oracle     = $self->{oracle};
    my $oracle_rep = $self->{oracle_rep};
    my $library    = $self->{library};
    my $batchname  = $self->{batchname};
    my $entity     = $self->{entity};
    my $runtype    = $self->{runtype};
    my $nr_engines = $self->{nr_engines};
    my $batch_size = $self->{batch_size};
    my $nr_retries = $self->{nr_retries};
    my $session_id = $self->{id};
    my $exc_tmpl   = $self->{exc_tmpl};
    my $db_audit   = $self->{db_audit};

    my $short_entity = Mx::Scheduler->entity_long2short( $entity );

    my $semaphore = Mx::Semaphore->new( key => $batchname, type => $Mx::Semaphore::TYPE_COUNT, count => 1, create => 1, logger => $logger, config => $config );

    $semaphore->acquire( alternate_key => $session_id, poll_interval => 5, max_retries => 120 );

    my @feeders = Mx::Datamart::Feeder->retrieve_all( batchname => $batchname, library => $library, oracle => $oracle, oracle_rep => $oracle_rep, logger => $logger, config => $config, semaphore => $semaphore );

    $self->{feeders} = [ @feeders ];

    foreach my $feeder ( @feeders ) {
        $feeder->update_tables( entity => $short_entity, semaphore => $semaphore ) unless $self->{noconfig};

        $self->{nr_engines} = $nr_engines = 0 if $feeder->nr_dynamic_tables == 0; 
    }

    $self->set_cmd_before( semaphore => $semaphore );

    unless ( $self->{noconfig} ) {
        $self->set_label( semaphore => $semaphore );

        $self->set_scanner( batch_size => $batch_size, nr_retries => $nr_retries, semaphore => $semaphore );

        $self->set_exception_template( name => $exc_tmpl, semaphore => $semaphore );

        $self->{filter}->install( semaphore => $semaphore );

        $self->{filter}->record( session_id => $session_id, db_audit => $db_audit );
    }

    return $nr_engines;
}

#-------------------#
sub finish_dm_batch {
#-------------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $config     = $self->{config};
    my $db_audit   = $self->{db_audit};
    my $session_id = $self->{id};
    my $entity     = $self->{entity};
    my $runtype    = $self->{runtype};
    my @feeders    = @{$self->{feeders}};

    my ( $job_id, $ref_data ) = $self->job_info();

    unless ( $job_id && $ref_data ) {
        if ( my $semaphore = Mx::Semaphore->new( key => $session_id, type => $Mx::Semaphore::TYPE_COUNT, logger => $logger, config => $config ) ) {
            $semaphore->external_release( cleanup => 1 ); 
        }
        return;
    }

    my $nr_dynamic_table_records = 0;
    foreach my $feeder ( @feeders ) {
        $feeder->set_job_id( $job_id );
        $feeder->set_ref_data( $ref_data );

        $nr_dynamic_table_records += $feeder->count_nr_records();

        $feeder->store( session_id => $session_id, entity => $entity, runtype => $runtype, db_audit => $db_audit );
    }

    if ( $self->{nr_engines} ) {
        my ( $nr_batches, $nr_items, $nr_missing_items, $missing_items_ref ) = $self->scanner_info( job_id => $job_id );

        $db_audit->record_scanner_info( session_id => $session_id, nr_engines => $self->{nr_engines}, batch_size => $self->{batch_size}, nr_retries => $self->{nr_retries}, nr_batches => $nr_batches, nr_items => $nr_items, nr_missing_items => $nr_missing_items, missing_items => $missing_items_ref, nr_table_records => $nr_dynamic_table_records );

        if ( $nr_missing_items ) {
            my $alert = Mx::Alert->new( name => 'batch_items', config => $config, logger => $logger );
            my $items = join ',', ( map { $_->[0] } @{$missing_items_ref} );
            $alert->trigger( level => $Mx::Alert::LEVEL_WARNING, values => [ $self->{name}, $self->{project}, $nr_missing_items, $items ], item => $self->{name} );
        }
    }
    else {
        $db_audit->record_scanner_info2( session_id => $session_id, nr_engines => $self->{nr_engines}, batch_size => $self->{batch_size}, nr_retries => $self->{nr_retries}, nr_table_records => $nr_dynamic_table_records );
    }

    $self->cleanup_scanner();
}

#-------------#
sub _mailbody {
#-------------#
    my ( $self ) = @_;

    my $config = $self->{config};
    my $type   = $self->{type};
    my $what   = $MXJ_IDENTIFIER{$type};
    my $body   = '';
    $body .= sprintf "%20s: %s\n", $what, $self->{name};
    $body .= sprintf "%20s: %s\n", 'Environment', $config->MXENV;
    $body .= sprintf "%20s: %s\n", 'Server', Mx::Util->hostname;
    $body .= sprintf "%20s: %s\n", 'Start', scalar(localtime($self->{start_time}));
    $body .= sprintf "%20s: %s\n", 'End', scalar(localtime($self->{end_time}));
    $body .= sprintf "%20s: %s\n", 'Exit code', $self->{exitcode};
    $body .= sprintf "\n";
    $body .= sprintf "%20s: %s\n", 'Scheduler jobstream', $self->{sched_jobstream} if $self->{sched_jobstream};
    $body .= sprintf "\n";
    $body .= sprintf "%20s: %s\n", 'Log files', $self->{logdir};
    $body .= sprintf "\n";
    $body .= sprintf "Generated by %s at %s\n", $0, scalar(localtime());
    return $body;
}

#-----------------------#
sub _analyze_answerfile {
#-----------------------#
    my ( $answerfile, $logger ) = @_;


    my $xp = XML::XPath->new( filename => $answerfile );

    #
    # STATUS
    #
    my $status = '';
    my $status_set = $xp->find('/GuiRoot/Script/Status');

    if ( $status_set->size() == 1 ) {
        $status = $status_set->get_node(1)->string_value;
    }

    my $ok = ( $status && $status ne 'Ended_Successfully' ) ? 0 : 1;

    my $failure_type;
    if ( $status eq 'Service_Failure' ) {
        $failure_type = 'service_failure';
    }

    #
    # ERRORS
    #
    my @errors;
    my $error_set = $xp->find('/GuiRoot/Script/ErrorsList/Errors/Error');

    foreach my $error ( $error_set->get_nodelist ) {
        my $prefix; my $suffix;
        foreach my $child ( $error->getChildNodes ) {
            if ( $child->getName() eq 'Prefix' ) {
                $prefix = $child->string_value;
            }
            elsif ( $child->getName() eq 'Suffix' ) {
                $suffix = $child->string_value;
            }
        }

        $logger->error("MX ANSWER: $suffix");

        if ( $prefix eq 'Overflow' or $suffix =~ /^Overflow / ) {
            $failure_type = 'dyntable_overflow';
        }
        elsif ( $prefix eq 'SYBASE-63' ) {
            $failure_type = 'sybase_timeout';
        }

        if ( $suffix =~ /Object having label .+ does not exist in table TRN_CPDF/ ) {
            $ok = 1;
            $logger->warn("forcing batch status to OK because of previous error message");
        }

        push @errors, { prefix => $prefix, suffix => $suffix };
    }

    #
    # WARNINGS
    #
    my @warnings; my $starttime;
    my $warning_set = $xp->find('/GuiRoot/Script/ErrorsList/Warnings/Warning');

    foreach my $warning ( $warning_set->get_nodelist ) {
        my $prefix; my $suffix;
        foreach my $child ( $warning->getChildNodes ) {
            if ( $child->getName() eq 'Prefix' ) {
                $prefix = $child->string_value;
            }
            elsif ( $child->getName() eq 'Suffix' ) {
                $suffix = $child->string_value;
            }
        }

        if ( $prefix eq 'Script started at' ) {
            $starttime = Mx::Util->proctime_to_epoch( $suffix );
        }

        push @warnings, { prefix => $prefix, suffix => $suffix };
    }

    #
    # TIMING
    #
    my ( $runtime, $cputime, $iotime );
    my $timing_set = $xp->find('/GuiRoot/Script/Timing');

    if ( $timing_set->size() == 1 ) {
        my $timing = $timing_set->get_node(1);

        foreach my $child ( $timing->getChildNodes ) {
            if ( $child->getName() eq 'ElapsedTime' ) {
                $runtime = Mx::Util->convert_seconds_inv( $child->string_value );
            }
            elsif ( $child->getName() eq 'CPUTime' ) {
                $cputime = Mx::Util->convert_seconds_inv( $child->string_value );
            }
            elsif ( $child->getName() eq 'IOTime' ) {
                $iotime = Mx::Util->convert_seconds_inv( $child->string_value );
            }
        }
    }

    return ( $ok, $runtime, $cputime, $iotime, $starttime, $failure_type );
}

#--------------------#
sub _analyze_logfile {
#--------------------#
    my ( $logfile, $ignore_warnings, $logger ) = @_;


    my $xp = XML::XPath->new( filename => $logfile );

    my @exceptions;
    my $exception_set = $xp->find('/LogRoot/MXException');

    foreach my $exception ( $exception_set->get_nodelist ) {
        my $level; my $description;
        foreach my $child ( $exception->getChildNodes ) {
            if ( $child->getName() eq 'Level' ) {
                $level = $child->string_value;
            }
            elsif ( $child->getName() eq 'Description' ) {
                $description = $child->string_value;
            }
        }

        if ( ( $ignore_warnings && $level eq 'Warning' ) || ( $level eq 'Info' ) ) {
            next;
        }

        push @exceptions, { level => $level, description => $description };

        $logger->error("MX ANSWER: $description");
    }

    my $ok = ( @exceptions ) ? 0 : 1;

    return $ok;
}

#---------------------#
sub _analyze_logfile2 {
#---------------------#
    my ( $logfile, $logger ) = @_;


    my $xp = XML::XPath->new( filename => $logfile );

    my $job_set = $xp->find('/LogRoot/GuiRoot/batch/getJobDetailsResponse/details/dapJob');

    my $error;
    if ( $job_set->size() == 1 ) {
        my $job = $job_set->get_node(1);

        foreach my $child ( $job->getChildNodes ) {
            if ( $child->getName() eq 'error' ) {
                $error = $child->string_value;
                $logger->error("MX LOG: $error");
            }
        }
    }

    return $error;
}

#--------------#
sub answerfile {
#--------------#
    my ( $self ) = @_;

    return $self->{answerfile};
}

#--------------#
sub headerfile {
#--------------#
    my ( $self ) = @_;

    return $self->{headerfile};
}

#-----------#
sub logfile {
#-----------#
    my ( $self ) = @_;

    return $self->{logfile};
}

#------------------#
sub mx_scripttypes {
#------------------#
    my ( $class ) = @_;


    return values %MXJ_IDENTIFIER;
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

