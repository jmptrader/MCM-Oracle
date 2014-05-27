package Mx::Job;

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Alert;
use Mx::DBaudit;
use Mx::Process;
use Time::Local;
use Carp;


#
# Attributes:
#
# name:              unique name of the job
# project:           project to which the job belongs
# type:              jobtype (see list below)
# command:           command that must be executed
# location:          server where the job must run
# days:              weekdays when the job must run
# starttime:         earliest runtime
# endtime:           latest runtime
# interval:          interval in seconds between consecutive runs for recurrent jobs
# runtimes:          list of times the job must run for singular jobs
# max_duration:      maximum duration of a job in seconds (0 to disable)
# exclusive:         boolean to indicate if the job must run exclusively
# alert:             alert that must be triggered when the job fails
# on_error:          what must be done when the job fails
#
#
# id
# status
# process
# last_runtime
# last_exitcode
# next_runtime
#


our $TYPE_SINGULAR      = 'singular';
our $TYPE_RECURRENT     = 'recurrent';

our $ACTION_IGNORE      = 'ignore';
our $ACTION_EXIT        = 'exit';

our $STATUS_INITIALIZED = 'initialized';
our $STATUS_WAITING     = 'waiting';
our $STATUS_READY       = 'ready';
our $STATUS_RUNNING     = 'running';
our $STATUS_COMPLETED   = 'completed';
our $STATUS_FAILED      = 'failed';
our $STATUS_FINISHED    = 'finished';
our $STATUS_TERMINATED  = 'terminated';
our $STATUS_DISABLED    = 'disabled';

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = { logger => $logger };

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $self->{name} = $args{name} ) {
        $logger->logdie("missing argument in initialisation of Murex job (name)");
    }

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument in initialisation of Murex job (config)");
    }

    my $job_configfile = $config->retrieve('JOB_CONFIGFILE');
    my $job_config     = Mx::Config->new( $job_configfile );

    my $job_ref;
    unless ( $job_ref = $job_config->retrieve("JOBS.$name") ) {
        $logger->logdie("job '$name' is not defined in the configuration file");
    }

    foreach my $param (qw( project type command location days starttime endtime interval runtimes max_duration exclusive alert on_error )) {
        unless ( exists $job_ref->{$param} ) {
            $logger->logdie("parameter '$param' for job '$name' is not defined in the configuration file");
        }
        $self->{$param} = $job_ref->{$param};
    }

    #
    # validate type
    #
    unless ( $self->{type} eq $TYPE_SINGULAR or $self->{type} eq $TYPE_RECURRENT ) {
        $logger->logdie("wrong job type specified: " . $self->{type});
    } 

    # 
    # validate command
    #
    while ( $self->{command} =~ /__(\w+)__/ ) {
        my $before = $`;
        my $ph     = $1;
        my $after  = $';
        $self->{command} = $before . $config->retrieve( $ph ) . $after;
    }

    #
    # check if the location is properly defined
    #
    unless ( $self->{location} =~ /^\d+$/ ) {
        $logger->logdie('wrong location specified: ', $self->{location});
    }

    #
    # validate days 
    #
    my @days = split ',', $self->{days};
    foreach my $day ( @days ) {
        unless ( $day =~ /^[0-6]$/ ) {
            $logger->logdie("wrong job days specified: " . $self->{days});
        }
    }
    @days = sort { $a <=> $b } @days;
    $self->{days} = [ @days ];

    #
    # validate starttime 
    #
    $self->{starttime} = _convert_time( $self->{starttime}, $logger );

    #
    # validate endtime 
    #
    $self->{endtime} = _convert_time( $self->{endtime}, $logger );

    #
    # validate interval
    #
    if ( $self->{type} eq $TYPE_RECURRENT ) {
        unless ( $self->{interval} =~ /^\d+$/ ) {
            $logger->logdie("wrong job interval specified: " . $self->{interval});
        }
        if ( $self->{interval} < 60 or $self->{interval} > 86400 ) {
            $logger->logdie("job interval must be between 60 and 86400 seconds");
        }
    }
    else {
        $self->{interval} = 0;
    }

    #
    # validate runtimes
    #
    if ( $self->{type} eq $TYPE_SINGULAR ) {
        my @runtimes = split ',', $self->{runtimes};
        my @new_runtimes = ();
        foreach my $runtime ( @runtimes ) {
            my $new_runtime = _convert_time( $runtime );
            if ( $new_runtime <= $self->{starttime} ) {
                $logger->warn("excluding job runtime $runtime as it is before the start time");
                next;
            }
            if ( $new_runtime >= $self->{endtime} ) {
                $logger->warn("excluding job runtime $runtime as it is after the start time");
                next;
            }
            push @new_runtimes, $new_runtime;
        }

        unless ( @new_runtimes ) {
            $logger->logdie("no valid job runtimes: " . $self->{runtimes});
        }

        @new_runtimes = sort { $a <=> $b } @new_runtimes;
        $self->{runtimes} = [ @new_runtimes ];
    }
    else {
        $self->{runtimes} = [];
    }

    #
    # validate max_duration
    #
    unless ( $self->{max_duration} =~ /^\d+$/ ) {
        $logger->logdie("wrong job duration specified: " . $self->{max_duration});
    }
    if ( $self->{max_duration} != 0 and ( $self->{max_duration} < 60 or $self->{max_duration} > 86400 ) ) {
        $logger->logdie("job duration must be between 60 and 86400 seconds");
    }

    #
    # validate exclusive
    #
    if ( $self->{exclusive} eq 'yes' ) {
        $self->{exclusive} = 1;
    }
    elsif ( $self->{exclusive} eq 'no' ) {
        $self->{exclusive} = 0;
    }
    else {
        $logger->logdie("wrong job exclusive setting specified: " . $self->{exclusive});
    }

    #
    # validate alert
    #
    if ( $self->{alert} ) {
        my $alert;
        unless ( $alert = Mx::Alert->new( name => $self->{alert}, config => $config, logger => $logger ) ) {
            $logger->logdie("wrong job alert specified: " . $self->{alert});
        }
        $self->{alert} = $alert;
    }

    # 
    # validate on_error
    #
    unless ( $self->{on_error} eq $ACTION_IGNORE or $self->{on_error} eq $ACTION_EXIT ) {
        $logger->logdie("wrong job error action specified: " . $self->{on_error});
    }

    $self->{last_runtime} = 0;
    $self->{status}       = $STATUS_INITIALIZED;

    $logger->info("job $name initialized");

    bless $self, $class;

    return $self;
}

#----------------#
sub retrieve_all {
#----------------#
   my ( $class, %args ) = @_;


    my @jobs = ();

    my $logger = $args{logger} or croak 'no logger defined';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $job_configfile = $config->retrieve('JOB_CONFIGFILE');
    my $job_config     = Mx::Config->new( $job_configfile );

    $logger->debug("scanning the configuration file for jobs");

    my $jobs_ref;
    unless ( $jobs_ref = $job_config->JOBS ) {
        $logger->logdie("cannot access the job section in the configuration file");
    }

    foreach my $name ( keys %{$jobs_ref} ) {
        my $job = Mx::Job->new( name => $name, config => $config, logger => $logger );
        push @jobs, $job;
    }

    return @jobs;
}

#------------#
sub schedule {
#------------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $name     = $self->{name};
    my $status   = $self->{status};
    my $db_audit = $args{db_audit};

    unless ( $status eq $STATUS_INITIALIZED or $status eq $STATUS_COMPLETED or $status eq $STATUS_FAILED ) {
        $logger->logdie("cannot schedule a job $name with as status $status");
    }

    my $type              = $self->{type};
    my @days              = @{$self->{days}};
    my @runtimes          = @{$self->{runtimes}};
    my $interval          = $self->{interval};
    my $full_last_runtime = $self->{last_runtime};
    my $starttime         = $self->{starttime};
    my $endtime           = $self->{endtime};

    my $full_current_time = time();
    my ( $sec, $min, $hour, $mday, $mon, $year, $current_day ) = localtime( $full_current_time );
    my $current_time = $hour * 3600 + $min * 60 + $sec;

    my $midnight = timelocal( 0, 0, 0, $mday, $mon, $year );

    my $not_today = 0;

    #
    # trivial case
    #
    if ( $current_time >= $endtime ) {
        $not_today = 1;
    }

    #
    # case for singular jobs
    #
    if ( $type eq $TYPE_SINGULAR and $current_time > $runtimes[-1] ) {
        $not_today = 1;
    }

    #
    # case for recurrent jobs
    #
    if ( $type eq $TYPE_RECURRENT and ( $full_last_runtime + $interval ) > ( $midnight + $endtime ) ) {
        $not_today = 1;
    }

    my $delta_days = 7;
    foreach my $day ( @days ) {
        my $delta = $day - $current_day;
        if ( $not_today and $delta == 0 ) {
            next;
        }
        $delta += 7 if $delta < 0;
        $delta_days = $delta if $delta < $delta_days;
    }

    $midnight += $delta_days * 86400;

    my $full_next_runtime;
    if ( $type eq $TYPE_SINGULAR ) {
        if ( $delta_days == 0 ) {
            my $delta_time = 999999;
            foreach my $runtime ( @runtimes ) {
                my $delta = $runtime - $current_time;
                next if $delta < 0;
                $delta_time = $delta if $delta < $delta_time;
            }
            if ( $delta_time == 999999 ) {
                $full_next_runtime = $midnight + 86400 + $runtimes[0];
            }
            else {
                $full_next_runtime = $full_current_time + $delta_time;
            }
        }
        else {
            $full_next_runtime = $midnight + $runtimes[0];
        }
    }
    else {
        if ( $delta_days == 0 ) {
            $full_next_runtime = $full_last_runtime + $interval;
            if ( $full_next_runtime < ( $midnight + $starttime ) ) {
                $full_next_runtime = $midnight + $starttime;
            }
        }
        else {
            $full_next_runtime = $midnight + $starttime;
        }
    }

    $self->{next_runtime} = $full_next_runtime;

    $self->{status} = $STATUS_WAITING;

    my $id = $self->{id} = $db_audit->record_job_start( name => $name, status => $STATUS_WAITING, next_runtime => $full_next_runtime );

    my $hrtime = localtime( $full_next_runtime );
    $logger->info("scheduling next run of job $name at $hrtime (id: $id)");

    return $full_next_runtime;
}

#-------------#
sub set_ready {
#-------------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $name     = $self->{name};
    my $id       = $self->{id};
    my $status   = $self->{status};
    my $db_audit = $args{db_audit};

    unless ( $status eq $STATUS_WAITING ) {
        $logger->logdie("cannot ready a job $name with as status $status");
    }

    $self->{status} = $STATUS_READY;

    $db_audit->update_job_status( id => $id, status => $status );

    $logger->info("job $name is ready to run (id: $id)");

    return 1;
}

#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $config   = $self->{config};
    my $name     = $self->{name};
    my $id       = $self->{id};
    my $status   = $self->{status};
    my $db_audit = $args{db_audit};

    $logger->info("running job $name (id: $id)");

    unless ( $status eq $STATUS_READY ) {
        $logger->logdie("cannot run a job $name with as status $status");
    }

    my $next_runtime = $self->{next_runtime};
    my $current_time = time();

    if ( $next_runtime > $current_time ) {
        my $errorstring = sprintf "job %s cannot run at %s when scheduled runtime is %s", $name, scalar(localtime($current_time)), scalar(localtime($next_runtime));
        $logger->logdie( $errorstring );
    }

    my $output  = $config->JOBLOGDIR . '/' . $id . '.stdout';
    my $command = "remote.pl -i " . $self->{location} . " -c '" . $self->{command} . "'";
      
    my $process; 
    unless ( $process = Mx::Process->background_run( command => $command, output => $output, logger => $logger, config => $config ) ) {
        $logger->error("failed to run job $name (id: $id)");
        $self->{status} = $STATUS_FAILED;
        $db_audit->record_job_run( id => $self->{id}, status => $STATUS_FAILED, starttime => time() );
        return 0;
    }

    $self->{process}      = $process;
    $self->{last_runtime} = time();
    $self->{status}       = $STATUS_RUNNING;

    $db_audit->record_job_run( id => $self->{id}, status => $STATUS_RUNNING, starttime => $self->{last_runtime} );

    return $process->pid;
}

#------------#
sub complete {
#------------#
    my ( $self, %args ) = @_;


    my $logger   = $self->{logger};
    my $config   = $self->{config};
    my $name     = $self->{name};
    my $id       = $self->{id};
    my $status   = $self->{status};
    my $db_audit = $args{db_audit};

    unless ( $status eq $STATUS_RUNNING ) {
        $logger->logdie("cannot complete a job $name with as status $status");
    }

    my $exitcode     = $self->{exitcode};
    my $exittime     = $self->{exittime};
    my $last_runtime = $self->{last_runtime};

    my $duration = $exittime - $last_runtime;

    $logger->info("job $name ended with exitcode $exitcode (id: $id)");

    my $reschedule = 1;
    if ( $exitcode == 0 ) {
        $self->{status} = $STATUS_COMPLETED;
    }
    else {
        my $on_error = $self->{on_error};
        if ( $on_error eq $ACTION_IGNORE ) {
            $self->{status} = $STATUS_FAILED;
        }
        elsif ( $on_error eq $ACTION_EXIT ) {
            $self->{status} = $STATUS_TERMINATED;
            $reschedule = 0;
        }
        if ( my $alert = $self->{alert} ) {
            $alert->trigger( level => $Mx::Alert::LEVEL_FAIL, values => [ $name, $self->{project}, $exitcode ], item => $name );
        }
    }

    $db_audit->record_job_end( id => $self->{id}, endtime => $exittime, duration => $duration, exitcode => $exitcode, status => $self->{status} );

    return $reschedule;
}

#------#
sub id {
#------#
    my ( $self ) = @_;


    return $self->{id};
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

#-----------#
sub project {
#-----------#
    my ( $self ) = @_;


    return $self->{project};
}

#--------#
sub type {
#--------#
    my ( $self ) = @_;


    return $self->{type};
}

#-----------#
sub command {
#-----------#
    my ( $self ) = @_;


    return $self->{command};
}

#------------#
sub location {
#------------#
    my ( $self ) = @_;


    return $self->{location};
}

#--------#
sub days {
#--------#
    my ( $self ) = @_;


    return @{$self->{days}};
}

#------------#
sub runtimes {
#------------#
    my ( $self ) = @_;


    return map { _convert_time_inv( $_ ) } @{$self->{runtimes}};
}

#------------#
sub interval {
#------------#
    my ( $self ) = @_;


    return $self->{interval};
}

#-------------#
sub starttime {
#-------------#
    my ( $self ) = @_;


    return _convert_time_inv( $self->{starttime} );
}

#-----------#
sub endtime {
#-----------#
    my ( $self ) = @_;


    return _convert_time_inv( $self->{endtime} );
}

#---------#
sub alert {
#---------#
    my ( $self ) = @_;


    if ( my $alert = $self->{alert} ) {
        return $alert->name;
    }
}

#------------#
sub on_error {
#------------#
    my ( $self ) = @_;


    return $self->{on_error};
}

#----------#
sub status {
#----------#
    my ( $self ) = @_;


    return $self->{status};
}

#----------------#
sub set_exittime {
#----------------#
    my ( $self, $exittime ) = @_;


    $self->{exittime} = $exittime;
}

#----------------#
sub set_exitcode {
#----------------#
    my ( $self, $exitcode ) = @_;


    $self->{exitcode} = $exitcode;
}

#-----------------#
sub _convert_time {
#-----------------#
    my ( $time, $logger ) = @_;


    if ( $time =~ /^(\d+):(\d+)$/ ) {
        my $hour = $1;
        my $min  = $2;
        unless ( $hour <= 23 and $min <= 59 ) {
            $logger->logdie("wrong job time specified: $time");
        }
        return $hour * 3600 + $min * 60;
    }

    $logger->logdie("wrong job time specified: $time");
}

#---------------------#
sub _convert_time_inv {
#---------------------#
    my ( $time ) = @_;


    my $hour = int( $time / 3600 );
    $time -= $hour * 3600;
    my $min = int( $time / 60 );
    $time -= $min * 60;
    my $sec = $time;

    return sprintf "%02d:%02d:%02d", $hour, $min, $sec;
}

1;
