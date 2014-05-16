package MLC::Task;

use strict;
use warnings;

use Carp;
use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Process;
use Mx::DBaudit;
use Mx::Mail;
use IO::File;
use File::Copy;

use constant INITIALIZED => 1;
use constant RUNNING     => 2;
use constant FINISHED    => 3;
use constant FAILED      => 4;

our $errstr = undef;

#
# Attributes
#
# name:              name of the task
# xmlfile:           XML task definition
# logdir:            directory used for all the input and output files
# start_time:        start time
# end_time:          end_time
# sched_jobstream:   jobstream name in the scheduler
# id:                unique identifier
# config:            a Mx::Config instance
# logger:            a Mx::Logger instance
# status:            see the defined constants above
# exitcode:          exitcode of the last run
# pid                PID of the Unix process
# db_audit:          a database connection for auditing
#

# Arguments:
#
# name:              name of the task
# template:          XML template file
# cfgfile:           values for the placeholders in the template
# cfghash:           values for the placeholders in the template
# sched_jobstream:   jobstream name in the scheduler
# logger:            a Mx::Logger instance
# config:            a Mx::Config instance
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
    # define and create the log directory
    #
    my $logdir;
    unless ( $logdir = _logdir( $name, $config->LOGDIR, $args{no_extra_logdir} ) ) {
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
        $errstr = 'missing argument in initialisation of MLC task (template)';
        $logger->error($errstr);
        return;
    }
    $self->{template} = $template;
    $self->{xmlfile}  = $self->{logdir} . '/task.xml';
    $self->{logfile}  = $self->{logdir} . '/task.log';

    unless ( _process_xmltemplate( $self, $template, $args{cfgfile}, $args{cfghash} ) ) {
        return;
    }

    $logger->info("using $template as XML template");

    #
    # Scheduler details
    #
    $self->{sched_jobstream} = $args{sched_jobstream};

    $self->{no_audit}    = $args{no_audit};

    $self->{status}      = INITIALIZED;

    bless $self, $class;
}

#
# Arguments:
#
# exclusive:     boolean indicating that this script cannot be run in parallel
# background:    boolean to indicate that the batch should be run in the background
# move_logfiles: move newly created logfiles to the logdir;
#
#-------#
sub run {
#-------#
    my ( $self, %args ) = @_;

 
    my $logger = $self->{logger};
    my $config = $self->{config};

    my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );
    $self->{db_audit} = $db_audit;

    #
    # determine the workdirectory from where the command must be launched
    #
    my $directory = $config->MXENV_ROOT . '/mlc';

    my $command = './launchmlc.sh -lts ' . $self->{xmlfile};

    my $hostname = Mx::Util->hostname();
    $self->{id} = 0;
    $self->{id} = $db_audit->record_task_start( cmdline => $command, hostname => $hostname, name => $self->{name}, logfile => $self->{logfile}, xmlfile => $self->{xmlfile}, sched_jobstream => $self->{sched_jobstream} ) unless $self->{no_audit};

    #
    # create a pidfile if the script should not be run in parallel with itself
    #
    $self->{process} = Mx::Process->new( descriptor => $self->{name}, logger => $self->{logger}, config => $config );
    if ( $args{exclusive} ) {
        unless ( $self->{process}->set_pidfile($0) ) {
            $errstr = 'not running exclusively';
            $self->{status}   = FAILED;
            $self->{exitcode} = 1;
            return;
        }
    }

    $self->{status}     = RUNNING;
    $self->{start_time} = time();


    my %logfiles_before;

    %logfiles_before = _logfiles( $directory ) if $args{move_logfiles};
    my ($success, $exitcode, $output, $pid) = Mx::Process->run( command => $command, directory => $directory, config => $config, logger => $logger );

    if ( $args{move_logfiles} ) {
        my %logfiles_after = _logfiles( $directory );

        my $logdir = $self->{logdir};

        foreach my $logfile ( keys %logfiles_after ) {
            unless ( $logfiles_before{$logfile} ) {
                my $sourcefile = $directory . '/' . $logfile;
                my $targetfile = $logdir    . '/' . $logfile; 

                $targetfile =~ s/\.log$/.txt/;

                if ( copy $sourcefile, $targetfile ) {
                    $logger->info("copied $sourcefile to $targetfile");

                    unless ( unlink $sourcefile ) {
                        $logger->warn("cannot remove $sourcefile");
                    }
                }
                else {
                    $logger->error("cannot copy $sourcefile to $targetfile");
                }
            }
        }
    }

    $self->{end_time}   = time();
    $self->{exitcode}   = $exitcode;
    $self->{status}     = ( $exitcode ) ? FAILED : FINISHED;
    $self->{pid}        = $pid;

    if ( $args{exclusive} ) {
        $self->{process}->remove_pidfile();
    }

    $db_audit->record_task_end( task_id => $self->{id}, pid => $self->{pid}, exitcode => $exitcode ) unless $self->{no_audit};
    $db_audit->close();
}

#--------#
sub mail {
#--------#
    my ( $self, %args ) = @_;
 
    my $config    = $self->{config};
    my $body      = _mailbody($self);
    my $what      = 'MLC task';
    my $subject;
    if ( $self->{status} == FINISHED ) {
        $subject = sprintf "%s: INFO: $what %s finished on %s", $config->MXENV, $self->{name}, $config->APPL_SRV;
    }
    elsif ( $self->{status} == FAILED ) {
        $subject = sprintf "%s: ALERT: $what %s failed on %s", $config->MXENV, $self->{name}, $config->APPL_SRV;
    }
    else {
        $errstr = 'can only send a mail when the status is FINISHED or FAILED';
        return;
    }
    my $logger = $self->{logger};
    my $mail = Mx::Mail->new( to => $args{address}, subject => $subject, body => $body, logger => $logger );
    $mail->send();
    return 1;
}

#-------------#
sub _mailbody {
#-------------#
    my ( $self ) = @_;
 
    my $config = $self->{config};
    my $what   = 'MLC task'; 
    my $body   = '';
    $body .= sprintf "%20s: %s\n", $what, $self->{name};
    $body .= sprintf "%20s: %s\n", 'Environment', $config->MXENV;
    $body .= sprintf "%20s: %s\n", 'Server', $config->APPL_SRV;
    $body .= sprintf "%20s: %s\n", 'Start', scalar(localtime($self->{start_time}));
    $body .= sprintf "%20s: %s\n", 'End', scalar(localtime($self->{end_time}));
    $body .= sprintf "%20s: %s\n", 'Exit code', $self->{exitcode};
    $body .= sprintf "\n";
    $body .= sprintf "%20s: %s\n", 'Scheduled jobstream', $self->{sched_jobstream} if $self->{sched_jobstream};
    $body .= sprintf "\n";
    $body .= sprintf "%20s: %s\n", 'Log file', $self->{logfile};
    $body .= sprintf "%20s: %s\n", 'XML file', $self->{xmlfile};
    $body .= sprintf "\n";
    $body .= sprintf "Generated by %s at %s\n", $0, scalar(localtime());
    return $body;
}

#------------#
sub exitcode {
#------------#
    my ($self) = @_;
 
    return $self->{exitcode};
}

#-----------#
sub _logdir {
#-----------#
    my ( $taskname, $basedir, $no_extra_logdir ) = @_;

 
    my ($day, $month, $year) = ( localtime() )[3..5];
    my $timestamp = sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;
    $basedir .= "/$timestamp";
    unless ( -d $basedir ) {
        unless ( mkdir( $basedir ) ) {
            $errstr = "cannot create $basedir: $!";
            return;
        }
    }

    my $logdir = $basedir . '/' . $taskname;
 
    if ( $no_extra_logdir ) {
        unless ( -d $logdir ) {
            unless ( mkdir( $logdir ) ) {
                $errstr = "cannot create $logdir: $!";
                return;
            }
        }
    }
    else {
        my $i = 1;
        while ( -d $logdir ) {
            $logdir = $basedir . '/' . $taskname . '_' . $i++;
        }
        unless ( mkdir( $logdir ) ) {
            $errstr = "cannot create $logdir: $!";
            return;
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
    my ($in, $out);
    unless ( $in = IO::File->new( $template, '<' ) ) {
        $errstr = "cannot open $template: $!";
        $logger->error($errstr);
        return;
    }
    unless ( $out = IO::File->new( $self->{xmlfile}, '>' ) ) {
        $errstr = 'cannot open ' . $self->{xmlfile} . ": $!";
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
 
    $params{__NAME__}    = $self->{name};
    $params{__LOGFILE__} = $self->{logfile};
 
    while ( my $line = <$in> ) {
        while ( $line =~ /__(\w+):PASSWORD__/ ) {
            my $user = $1;
            my $account;
            unless ( $account = Mx::Account->new( name => $user, config => $self->{config}, logger => $self->{logger} ) ) {
                $errstr = "cannot retrieve account $user";
                $logger->error($errstr);
            }
            my $password = $account->password();
            $line =~ s/__$user:PASSWORD__/$password/g;
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
            else {
                $errstr = "no substitution found for placeholder $ph in template file $template";
                $logger->error($errstr);
                return;
            }
        }
        print $out $line;
    }
    $in->close;
    $out->close;
    return 1;
}

#-------------#
sub _logfiles {
#-------------#
    my ( $directory ) = @_;

    
    my %logfiles = ();

    unless ( opendir DIR, $directory ) {
        return;
    }

    foreach my $file ( readdir(DIR) ) { 
        $logfiles{$file} = 1 if $file =~ /\.log$/;
    }

    closedir(DIR);

    return %logfiles;
}

1;
