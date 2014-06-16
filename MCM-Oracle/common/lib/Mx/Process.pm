package Mx::Process;

use strict;
no strict 'refs';

use Carp;
use Cwd;
use IPC::Cmd;
use POSIX qw(:sys_wait_h setsid);
use Fcntl qw( :seek );
use Time::HiRes qw( usleep );
use Apache2::SubProcess;
use File::Basename;
use Text::ParseWords;
use Config;
use Mx::Util;
use Mx::DBaudit;
use Mx::Error;

our $errstr = undef;

our $OTHER        = 1;
our $MXSESSION    = 2;
our $ABSESSION    = 3;
our $MX_UNKNOWN   = 4;
our $JAVA_UNKNOWN = 5;
our $MXSCRIPT     = 6;
our $DMSCRIPT     = 7;
our $CDIRECT      = 8;

our $PROCESS_MODEL;

my $LINUX_BOOTTIME;
my $LINUX_TOTAL_MEMORY;

use constant DEFAULT_POLL_INTERVAL => 5;

#
# Attributes:
#
# pid:            the process pid
# ppid:           the parent's process id
# uid:            the owner of the process
# cmdline:        the full commandline 
# hostname:       server where the process is running
# starttime:      start time of the process
# descriptor:     a string which is used to create a pidfile (optional)
# label:          a string describing the process (optional)
# pattern:        a string which must be present in the commandline (optional)
# pidfile:        corresponding pidfile (optional)
# pidfile_mtime:  last modification time of the pidfile (optional)
# logger:         a Mx::Logger instance
# config:         a Mx::Config instance
# type:           which type of process
# win_user:       Windows user which started the session
# mx_nick:        Murex nick name for the session
# mx_pid:         Murex pid, which is different from the Unix pid
# mx_client_host: Murex client hostname
# mx_client_ip:   Murex client ip address
# mx_scripttype
# mx_scriptname
# mx_sessionid
# dummy           Boolean indicating this process is not a real one (used for autobalance)
#
# Optional performance attributes:
#
# pcpu:           percentage cpu
# pmem:           percentage memory
# vsz:            virtual memory size
# rss:            resident set size
# nlwp:           number of LWP's
# nfh:            number of FH's
# cputime:        number of seconds spent on the cpu
#

# in case of a mxscript:
#
# project:        name of the project to which the script belongs
# sched_js:       TWS jobstream to which the script belongs
#

#
# Optional arguments:
#
# light:          boolean indicating if the type of process must be determined (mxsession or not)
#
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $args{logger} or croak 'no logger defined.';
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie('missing argument in initialisation of process (config)');
    }

    if ( $args{pid} ) {
        $self->{pid} = $args{pid};
    }
    elsif ( $args{pidfile} ) {
        $self->{pid}           = _read_pidfile( $args{pidfile}, $logger ) or return;
        $self->{pidfile}       = $args{pidfile};  
        $self->{pidfile_mtime} = (stat($args{pidfile}))[9];
    }
    else {
        $self->{pid} = $$;
    }

    $self->{descriptor} = $args{descriptor};
    $self->{pattern}    = $args{pattern};
    $self->{label}      = $args{label};

    $self->{hostname}   = $args{hostname} || Mx::Util->hostname();
    $self->{ostype}     = Mx::Process->ostype;

    bless $self, $class;

    if ( $args{dummy} ) {
        $self->{dummy} = 1;
        return $self;
    }

    if ( $args{light} ) {
        $self->{uid}          = $args{uid};
        $self->{ppid}         = $args{ppid};
        $self->{cmdline}      = $args{cmdline};
        $self->{mx_sessionid} = $args{mx_sessionid};
        return $self;
    }

    return unless $self->update_performance;

    if ( $self->{uid} == $< ) {
        return unless $self->get_full_cmdline;
    }

    _analyze_cmdline( $self );

    return $self;
}

#--------#
sub list {
#--------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $hostname = Mx::Util->hostname();

    my @pid_list = Mx::Process->thin_list();

    my @processes;
    foreach my $entry ( @pid_list ) {  
        my $process = Mx::Process->new( pid => $entry->[0], hostname => $hostname, logger => $logger, config => $config );

        push @processes, $process if $process;
    } 

    return @processes;
}

#-------------#
sub thin_list {
#-------------#
    my ( $class, %args ) = @_;


    my @list;

    opendir DIR, '/proc';

    my @pids;
    while ( my $pid = readdir( DIR ) ) {
        next unless $pid =~ /^\d+$/;

        my ( $uid, $starttime ) = (stat('/proc/' . $pid))[4,9]; 

        next unless $uid == $<;

        push @list, [ $pid, $starttime ];
    }

    closedir( DIR );

    return @list;
}

#---------------------#
sub _solaris_procinfo {
#---------------------#
    my ( $pid, $logger ) = @_;


    my %procinfo = ();

    my $psinfo_file = '/proc/' . $pid . '/psinfo';

    unless ( open PSINFO, $psinfo_file ) {
        $logger->error("unable to open $psinfo_file: $!") if $logger;
        return;
    }

    my $psinfo;
    unless ( read( PSINFO, $psinfo, 257 ) == 257 ) {
        $logger->error("unable to read from $psinfo_file: $!") if $logger;
        return;
    }

    close( PSINFO );

    my @fields = qw( pr_flag pr_nlwp pr_pid pr_ppid pr_pgid pr_sid pr_uid pr_euid pr_gid pr_egid pr_addr pr_size pr_rssize pr_pad1 pr_ttydev pr_pctcpu pr_pctmem pr_start pr_time pr_ctime pr_fname pr_psargs pr_wstat pr_argc pr_argv pr_envp pr_dmodel );

    my $packstring1; my $packstring2;
    my $process_model = Mx::Process->process_model;
    if ( $process_model == 32 ) {
        $packstring1 = 'iiiiiiiiiiIiiiiSSa8a8a8Z16Z80iiIIc';
        $packstring2 = 'LL';
    }
    elsif ( $process_model == 64 ) {
        $packstring1 = 'iiiiiiiiiiQQQQqssxxxxa16a16a16Z16Z80iiQQc';
        $packstring2 = 'QQ';
    }
    else {
        $logger->logdie("invalid process model: $process_model");
    }

    @procinfo{ @fields } = unpack( $packstring1, $psinfo );

    $procinfo{pr_start} = ( unpack( $packstring2, $procinfo{pr_start} ) )[0];
    $procinfo{pr_time}  = ( unpack( $packstring2, $procinfo{pr_time} ) )[0];

    $procinfo{pr_pctcpu} /= 327.68;
    $procinfo{pr_pctmem} /= 327.68;

    return \%procinfo;
}

#-------------------#
sub _linux_procinfo {
#-------------------#
    my ( $pid, $logger ) = @_;


    my %procinfo = ();

    my $psinfo_file = '/proc/' . $pid . '/stat';

    unless ( open PSINFO, $psinfo_file ) {
        $logger->error("unable to open $psinfo_file: $!") if $logger;
        return;
    }

    my $psinfo;
    unless ( $psinfo = <PSINFO> ) {
        $logger->error("unable to read from $psinfo_file: $!") if $logger;
        return;
    }

    close( PSINFO );

    my $herz     = POSIX::sysconf( &POSIX::_SC_CLK_TCK );
    my $pagesize = POSIX::sysconf( &POSIX::_SC_PAGESIZE );

    my @fields = qw( pr_pid pr_progname pr_state pr_ppid pr_pgid pr_sid pr_tty pr_ttypgid pr_flags pr_minflt pr_cminflt pr_majflt pr_cmajflt pr_utime pr_stime pr_cutime pr_cstime pr_priority pr_nice pr_nlwp pr_itrealvalue pr_start pr_size pr_rssize );

    @procinfo{ @fields } = split ' ', $psinfo;

    $procinfo{pr_utime} /= $herz;
    $procinfo{pr_stime} /= $herz;
    $procinfo{pr_start} /= $herz;

    $procinfo{pr_time} = sprintf "%d", $procinfo{pr_utime} + $procinfo{pr_stime};

    $procinfo{pr_start}  += Mx::Process->linux_boottime;
    $procinfo{pr_start}   = sprintf "%d", $procinfo{pr_start};
    $procinfo{pr_rssize} *= $pagesize;

    my $runtime = ( time() - $procinfo{pr_start} ) || 1;
    $procinfo{pr_pctcpu} = 100 * $procinfo{pr_time} / $runtime;
    $procinfo{pr_pctmem} = 100 * $procinfo{pr_rssize} / Mx::Process->linux_total_memory;

    $procinfo{pr_uid} = (stat('/proc/' . $pid))[4];

    $procinfo{pr_dmodel} = 2; # hardcode to 64bit
    $procinfo{pr_psargs} = $procinfo{pr_progname}; # better than nothing

    $procinfo{pr_rssize} /= 1024;
    $procinfo{pr_size}   /= 1024;

    return \%procinfo;
}

#-------------#
sub full_list {
#-------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger};

    my @list = ();

    my $ostype = Mx::Process->ostype;

    my $procinfo_function;
    if ( $ostype eq 'solaris' ) {
        $procinfo_function = '_solaris_procinfo';
    }
    elsif ( $ostype eq 'linux' ) {
        $procinfo_function = '_linux_procinfo';
    }
    else {
        $logger->logdie("unknown OS type: $ostype");
    }

    opendir DIR, '/proc';

    while ( my $pid = readdir( DIR ) ) {
        next unless $pid =~ /^\d+$/;

        if ( my $procinfo = &$procinfo_function( $pid, $logger ) ) {
            my $uid  = $procinfo->{pr_uid};
            my $pcpu = sprintf "%.2f", $procinfo->{pr_pctcpu};
            my $pmem = sprintf "%.2f", $procinfo->{pr_pctmem};

            push @list, [ $uid, $pcpu, $pmem ];
        }
    }

    closedir( DIR );

    return @list;
}

#----------------#
sub _parent_list {
#----------------#
    my ( %args ) = @_;


    my $logger = $args{logger};

    my %parent = ();

    my $ostype = Mx::Process->ostype;

    my $procinfo_function;
    if ( $ostype eq 'solaris' ) {
        $procinfo_function = '_solaris_procinfo';
    }
    elsif ( $ostype eq 'linux' ) {
        $procinfo_function = '_linux_procinfo';
    }
    else {
        $logger->logdie("unknown OS type: $ostype");
    }

    opendir DIR, '/proc';

    while ( my $pid = readdir( DIR ) ) {
        next unless $pid =~ /^\d+$/;

        my ( $uid ) = (stat('/proc/' . $pid))[4];

        next unless $uid == $<;

        if ( my $procinfo = &$procinfo_function( $pid, $logger ) ) {
            $parent{$pid} = $procinfo->{pr_ppid};
        }
    }

    closedir( DIR );

    return %parent;
}

#-------------------#
sub all_descendants {
#-------------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    $logger->debug("searching for all processes with as ancestor pid " . $self->{pid});

    my @processes    = ();
    my %is_present   = ();
    my %is_scanned   = ();

    my %parent = _parent_list( logger => $logger );

    while ( my ( $pid, $ppid ) = each %parent ) {
        next unless $self->pid == $ppid;

        if ( my $process = Mx::Process->new( pid => $pid, logger => $logger, config => $config ) ) {
            push @processes, $process;
            $is_present{$pid} = 1;
            my $cmdline = $process->cmdline;
            $logger->debug("found process with pid $pid (cmdline: $cmdline)");
        }
    }

    while ( 1 ) {
        my @new_processes = ();

        foreach my $process ( @processes ) {
            next if $is_scanned{ $process->pid };

            while ( my ( $pid, $ppid ) = each %parent ) {
                next if $is_present{pid};
                next unless $process->pid == $ppid;

                if ( my $process = Mx::Process->new( pid => $pid, logger => $logger, config => $config ) ) {
                    push @new_processes, $process;
                    $is_present{$pid} = 1; 
                    my $cmdline = $process->cmdline;
                    $logger->debug("found process with pid $pid (cmdline: $cmdline)"); 
                }
            }

            $is_scanned{ $process->pid } = 1;
        }

        last unless @new_processes;

        push @processes , @new_processes;
    }

    return @processes;
}

#----------------------#
sub update_performance {
#----------------------#
    my ( $self ) = @_;


    my $ostype = $self->{ostype};
    my $pid    = $self->{pid};
    my $logger = $self->{logger};

    my $procinfo_function;
    if ( $ostype eq 'solaris' ) {
        $procinfo_function = '_solaris_procinfo';
    }
    elsif ( $ostype eq 'linux' ) {
        $procinfo_function = '_linux_procinfo';
    }
    else {
        $logger->logdie("unknown OS type: $ostype");
    }

    if ( my $procinfo = &$procinfo_function( $pid, $logger ) ) {
        $self->{uid}         = $procinfo->{pr_uid};
        $self->{ppid}        = $procinfo->{pr_ppid};
        $self->{cmdline_80}  = $procinfo->{pr_psargs};
        $self->{starttime}   = $procinfo->{pr_start};

        $self->{pcpu}        = sprintf "%.1f", $procinfo->{pr_pctcpu};
        $self->{pmem}        = sprintf "%.1f", $procinfo->{pr_pctmem};
        $self->{vsz}         = $procinfo->{pr_size};
        $self->{rss}         = $procinfo->{pr_rssize};
        $self->{nlwp}        = $procinfo->{pr_nlwp};
        $self->{cputime}     = $procinfo->{pr_time};

        my $pr_dmodel = $procinfo->{pr_dmodel};
        if ( $pr_dmodel eq '1' ) {
            $self->{process_model} = 32;
        }
        elsif ( $pr_dmodel eq '2' ) {
            $self->{process_model} = 64;
        }
        else {
            $logger->logdie("invalid process model ($pr_dmodel)");
        }

        if ( $ostype eq 'solaris' ) {
            $self->{_arg_vector} = $procinfo->{pr_argv};
            $self->{_nr_args}    = $procinfo->{pr_argc};
            $self->{_env_vector} = $procinfo->{pr_envp};
        }

        my $fhdir = '/proc/' . $pid . '/fd';

        if ( opendir DIR, $fhdir ) {
            my @dirs = readdir(DIR);
            closedir(DIR);
            $self->{nfh} = @dirs - 2;
        }

        return 1;
    }

    return;
}

#-------------------------#
sub cpu_seconds_and_vsize {
#-------------------------#
    my ( $class, $pid ) = @_;


    if ( Mx::Process->ostype eq 'solaris' ) {
        if ( my $procinfo = _solaris_procinfo( $pid ) ) {
            return ( $procinfo->{pr_time}, $procinfo->{pr_size} );
        }
    }
    elsif ( Mx::Process->ostype eq 'linux' ) {
    }
}

#--------------------#
sub get_full_cmdline {
#--------------------#
    my ( $self ) = @_;


    my $ostype = $self->{ostype};

    my @cmdline;
    if ( $ostype eq 'solaris' ) {
        unless ( $self->{_nr_args} ) {
            $self->update_performance or return;
        }

        my $buffer;

        my $as_file = '/proc/' . $self->{pid} . '/as';

        unless ( open AS, $as_file ) {
            $self->{logger}->error("get_full_cmdline: unable to open $as_file: $!");
            return;
        }

        my $pointersize = ( $self->{process_model} == 32 ) ? 4 : 8;
        my $packstring  = ( $self->{process_model} == 32 ) ? 'L' : 'Q';

        seek( AS, $self->{_arg_vector}, SEEK_SET );

        read( AS, $buffer, $pointersize * $self->{_nr_args} );

        my @addresses = unpack( $packstring x $self->{_nr_args}, $buffer );

        seek( AS, $self->{_env_vector}, SEEK_SET );

        read( AS, $buffer, $pointersize );

        my $env_address = unpack( $packstring, $buffer );

        push @addresses, $env_address;

        my $address = shift @addresses;

        seek( AS, $address, SEEK_SET );

        while ( my $next_address = shift @addresses ) {
            my $length  = $next_address - $address;

            return if $length < 0;

            read( AS, $buffer, $length );

            chop($buffer); # remove null byte

            push @cmdline, $buffer;

            $address = $next_address;
        }

        close(AS);
    }
    elsif ( $ostype eq 'linux' ) {
        my $as_file = '/proc/' . $self->{pid} . '/cmdline';

        unless ( open AS, $as_file ) {
            $self->{logger}->error("get_full_cmdline: unable to open $as_file: $!");
            return;
        }

        my $line = <AS>;

        close(AS);

        @cmdline = split '\0', $line;
    }

    my $option = ''; my %cmdline;
    foreach my $item ( @cmdline ) {
        if ( $option && $item !~ /^\-/ ) { 
            $cmdline{$option} = $item;
            $option = '';
        }
        elsif ( $item =~ /^\-D(\w+)=(.+)$/ ) {
            $cmdline{$1} = $2;
            $option = '';
        }
        elsif ( $item =~ /^\/(\w+):(.+)$/ ) {
            $cmdline{$1} = $2 if $1 ne 'MXJ_JVM';
            $option = '';
        }
        elsif ( $item =~ /^\/(\w+)$/ ) {
            $cmdline{$1} = 1;
            $option = '';
        }
        elsif ( $item =~ /^\-(\w+)$/ ) {
            $option = $1;
        }
        else {
            $option = '';
        }
    }

    $self->{cmdline_array} = [ @cmdline ];
    $self->{cmdline_hash}  = { %cmdline };

    return 1;
}

#-----------------#
sub process_model {
#-----------------#
    my ( $self ) = @_;


    if ( ref($self) eq 'Mx::Process' ) {
        return $self->{process_model};
    }
    else {
        if ( ! $PROCESS_MODEL ) {
            $PROCESS_MODEL = ( $Config{longsize} == 8 ) ? 64 : 32;
        }

        return $PROCESS_MODEL;
    }
}

#----------#
sub ostype {
#----------#
    my ( $self ) = @_;


    if ( ref($self) eq 'Mx::Process' ) {
        return $self->{ostype};
    }
    else {
        return $^O;
    }
}

#------------------#
sub linux_boottime {
#------------------#
    my ( $class ) = @_;


    unless ( $LINUX_BOOTTIME ) {
        if ( open FH, '/proc/stat' ) {
            while ( <FH> ) {
                if ( /^btime (\d+)$/ ) {
                    $LINUX_BOOTTIME = $1;
                    last;
                }
            }
            close(FH);
        }
    }

    return $LINUX_BOOTTIME;
}

#----------------------#
sub linux_total_memory {
#----------------------#
    my ( $class ) = @_;


    unless ( $LINUX_TOTAL_MEMORY ) {
        if ( open FH, '/proc/meminfo' ) {
            while ( <FH> ) {
                if ( /^MemTotal:\s+(\d+) kB$/ ) {
                    $LINUX_TOTAL_MEMORY = $1 * 1024; 
                    last;
                }
            }
            close(FH);
        }
    }

    return $LINUX_TOTAL_MEMORY;
}

#--------------------#
sub is_still_running {
#--------------------#
    my ( $self ) = @_;


    return if $self->{dummy};

    my $procdir = '/proc/' . $self->{pid};

    unless ( -d $procdir ) {
        return 0;
    }

    my $procinfo_function = '_' . $self->{ostype} . '_procinfo';

    if ( my $procinfo = &$procinfo_function( $self->{pid}, $self->{logger} ) ) {
        return $self->{starttime} == $procinfo->{pr_start};
    }

    return 0;
}

#-------------------#
sub wait_for_finish {
#-------------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $pid    = $self->{pid};

    $logger->debug("waiting for process $pid to finish");

    my $rv = waitpid( $pid, 0 );

    if ( $rv == $pid ) {
        my $exitvalue = $? >> 8;
        $logger->debug("process $pid ended with exitvalue $exitvalue");
        return $exitvalue;
    }
    else {
        $logger->error("cannot wait for finish of process $pid");
        return -1;
    }
}

#-----------------------#
sub wait_for_any_finish {
#-----------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger};

    my $processes_ref;
    unless ( ( $processes_ref = $args{processes} ) && ( ref( $processes_ref ) eq 'ARRAY' ) ) {
        $logger->logdie("wait_for_any_finish: missing or incorrect argument (processes)");
    }

    my $nr_running_processes = @{$processes_ref};

    $logger->debug("$nr_running_processes running processes, waiting for any child process to finish");

    my $pid = waitpid( -1, 0 );

    if ( $pid > 0 ) {
        my $exitvalue = $? >> 8;

        my $process;
        for ( my $i = 0; $i < $nr_running_processes; $i++ ) {
            if ( $processes_ref->[$i]->pid == $pid ) {
                $process = splice $processes_ref, $i, 1;
                last;
            }
        }

        unless ( $process ) {
            $logger->error("child process $pid ended with exitvalue $exitvalue but is not present in the list");
            return;
        }

        $process->{exitvalue} = $exitvalue;

        $logger->debug("process $pid ended with exitvalue $exitvalue");

        return $process;
    }

    $logger->error("cannot wait for finish of any process (returnvalue: $pid)");
    return;
}

#-----------------#
sub check_pidfile {
#-----------------#
    my ( $self ) = @_;


    my $logger        = $self->{logger};
    my $config        = $self->{config};
    my $pidfile       = $self->{pidfile};
    my $pidfile_mtime = $self->{pidfile_mtime};

    unless ( $pidfile ) {
        $logger->error("check_pidfile: no pidfile defined");
        return;
    }

    unless ( -f $pidfile ) {
        $logger->error("check_pidfile: pidfile $pidfile does not exist");
        return 0;
    }

    my $current_pidfile_mtime = (stat($pidfile))[9];

    if ( $current_pidfile_mtime == $pidfile_mtime ) {
        return 1;
    }

    $self->{pidfile_mtime} = $current_pidfile_mtime;

    my $pid = _read_pidfile( $pidfile, $logger );

    unless ( $pid ) {
        return;
    }

    if ( $pid == $self->{pid} ) {
        return 1;
    }

    $logger->debug("check_pidfile: pidfile $pidfile contains a new pid ($pid)");

    $self->{pid} = $pid;

    unless ( $self->update_performance ) {
        $logger->error("check_pidfile: pidfile $pidfile contains a pid ($pid) that does not exist");
        return 0;
    }

    unless ( $self->get_full_cmdline ) {
        $logger->error("check_pidfile: pidfile $pidfile contains a pid ($pid) that has a wrong owner");
        return 0;
    }

    unless ( _analyze_cmdline( $self ) ) {
        $logger->error("check_pidfile: the new process cmdline is not matching");
        return 0;
    }

    return 2;
}

#--------#
sub kill {
#--------#
    my ($self, %args) = @_;

   
    my $logger       = $self->{logger};
    my $config       = $self->{config};
    my $pid          = $self->{pid};
    my $mx_sessionid = $self->{mx_sessionid};

    my $db_audit;
    if ( $mx_sessionid ) {
        $db_audit = $args{db_audit} || Mx::DBaudit->new( logger => $logger, config => $config );
    }

    my @descendants = ();
    if ( $args{recursive} ) {
        $logger->debug("trying to recursively kill process $pid"); 
        @descendants = $self->all_descendants;
    }
    else {
        $logger->debug("trying to kill process $pid"); 
    }

    kill 15, $pid;

    my $count = 0;
    while ( $self->is_still_running ) {
        if ( ++$count == 10 ) {
            last;
        }

        usleep( 100000 );
    }

    unless ( $count == 10 ) {
        $logger->debug("process $pid is killed");

        if ( $mx_sessionid ) {
            $db_audit->mark_for_kill( session_id => $mx_sessionid );
            $db_audit->close() unless $args{db_audit};
        }

        foreach my $process ( @descendants ) {
            $process->kill( db_audit => $args{db_audit} );
        }

        return 1;
    }

    $logger->debug("trying to kill (hard) process $pid"); 

    kill 9, $pid;

    $count = 0;
    while ( $self->is_still_running ) {
        if ( ++$count == 10 ) {
            last;
        }

        usleep( 100000 );
    }

    unless ( $count == 10 ) {
        $logger->debug("process $pid is killed");

        if ( $mx_sessionid ) {
            $db_audit->mark_for_kill( session_id => $mx_sessionid );
            $db_audit->close() unless $args{db_audit};
        }

        foreach my $process ( @descendants ) {
            $process->kill( db_audit => $args{db_audit} );
        }

        return 1;
    }

    $logger->error("unable to kill process $pid");
    if ( $mx_sessionid ) {
        $db_audit->close() unless $args{db_audit};
    }

    return 0;
}

#
# This method can be called as an instance and a class method
#
#-------#
sub pid {
#-------#
    my ( $self ) = @_;

    if ( ref($self) eq 'Mx::Process' ) {
        return $self->{pid};
    }
    else {
        return $$;
    }
}

#-------#
sub uid {
#-------#
    my ( $self ) = @_;

    return $self->{uid};
}

#------------#
sub username {
#------------#
    my ( $self ) = @_;

    return ( getpwuid( $self->{uid} ) )[0];
}

#--------#
sub ppid {
#--------#
    my ( $self ) = @_;

    return $self->{ppid};
}

#-----------#
sub cmdline {
#-----------#
    my ( $self ) = @_;


    if ( $self->{cmdline_array} ) {
        return ( join ' ', @{$self->{cmdline_array}} );
    }

    return $self->{cmdline_80};
}

#-----------------#
sub cmdline_array {
#-----------------#
    my ( $self ) = @_;


    if ( $self->{cmdline_array} ) {
        return @{$self->{cmdline_array}};
    }
}

#----------------#
sub cmdline_hash {
#----------------#
    my ( $self ) = @_;


    if ( $self->{cmdline_hash} ) {
        return %{$self->{cmdline_hash}};
    }
}

#------------#
sub hostname {
#------------#
    my ( $self ) = @_;

    return $self->{hostname};
}

#--------#
sub _cwd {
#--------#
    my ( $self ) = @_;


    if ( $self->{ostype} eq 'solaris' ) {
        return readlink( '/proc/' . $self->{pid} . '/path/cwd' );
    }
    elsif ( $self->{ostype} eq 'linux' ) {
        return readlink( '/proc/' . $self->{pid} . '/cwd' );
    }
}

#--------------#
sub _open_file {
#--------------#
    my ( $self, $fd ) = @_;


    if ( $self->{ostype} eq 'solaris' ) {
        my $file = '/proc/' . $self->{pid} . '/path/' . $fd;
        if ( -e $file ) { 
            return readlink( $file );
        }
    }
    elsif ( $self->{ostype} eq 'linux' ) {
        my $file = '/proc/' . $self->{pid} . '/fd/' . $fd;
        if ( -e $file ) { 
            return readlink( $file );
        }
    }
}

#-----------------#
sub env_variables {
#-----------------#
    my ( $self, $pid ) = @_;


    $pid ||= $self->{pid};
    my $ostype = $self->ostype();

    my %variables;
    if ( $ostype eq 'solaris' ) {
        open CMD, "/usr/bin/pargs -e $pid|";
        while ( my $line = <CMD> ) {
            if ( $line =~ /^envp\[\d+\]: (\w+)=(.*)$/ ) {
                $variables{$1} = $2;
            }
        }
        close(CMD);
    }
    elsif ( $ostype eq 'linux' ) {
        my $file = '/proc/' . $pid . '/environ';
        if ( open FH, "$file" ) {
            my $line = <FH>;
            close(FH);
            foreach my $entry ( split /\0/, $line ) {
                my ( $key, $value ) = split /=/, $entry, 2;
                $variables{$key} = $value;
            }
        }
    }

    return %variables;
}

#-----------#
sub project {
#-----------#
    my ( $self, $pid ) = @_;

    return $self->{project};
}

#------------#
sub sched_js {
#------------#
    my ( $self, $pid ) = @_;

    return $self->{sched_js};
}

#-------------#
sub starttime {
#-------------#
    my ($self) = @_;

    return $self->{starttime};
}

#
# This method is both a getter and a setter
#
#--------------#
sub descriptor {
#--------------#
    my ( $self, $descriptor ) = @_;

    $self->{descriptor} = $descriptor if $descriptor;
    return $self->{descriptor};
}

#---------#
sub label {
#---------#
    my ( $self, $label ) = @_;

    $self->{label} = $label if $label;
    return $self->{label};
}

#-----------#
sub pattern {
#-----------#
    my ($self) = @_;

    return $self->{pattern};
}

#--------#
sub type {
#--------#
    my ($self) = @_;

    return $self->{type};
}

#------------#
sub win_user {
#------------#
    my ($self) = @_;

    return $self->{win_user};
}

#-------------#
sub full_name {
#-------------#
    my ( $self, $full_name ) = @_;


    $self->{full_name} = $full_name if $full_name;
    return $self->{full_name};
}

#-----------------#
sub session_count {
#-----------------#
    my ( $self, $session_count ) = @_;


    $self->{session_count} = $session_count if $session_count;
    return $self->{session_count};
}

#-----------#
sub mx_user {
#-----------#
    my ( $self, $mx_user ) = @_;


    $self->{mx_user} = $mx_user if $mx_user;
    return $self->{mx_user};
}

#------------#
sub mx_group {
#------------#
    my ( $self, $mx_group ) = @_;


    $self->{mx_group} = $mx_group if $mx_group;
    return $self->{mx_group};
}

#-----------#
sub mx_desk {
#-----------#
    my ($self) = @_;

    return $self->{mx_desk};
}

#------------#
sub app_user {
#------------#
    my ( $self ) = @_;


    return $self->{app_user};
}

#-------------#
sub app_group {
#-------------#
    my ( $self ) = @_;


    return $self->{app_group};
}

#------------#
sub app_desk {
#------------#
    my ($self) = @_;


    return $self->{app_desk};
}

#------------------#
sub mx_client_host {
#------------------#
    my ($self) = @_;


    return $self->{mx_client_host};
}

#----------------#
sub mx_client_ip {
#----------------#
    my ($self) = @_;

    return $self->{mx_client_ip};
}

#-----------#
sub mx_nick {
#-----------#
    my ($self) = @_;

    return $self->{mx_nick};
}

#------------------#
sub mx_scannernick {
#------------------#
    my ($self) = @_;

    return $self->{mx_scannernick};
}

#---------#
sub mxres {
#---------#
    my ($self) = @_;


    if ( $self->{cmdline_hash} ) {
        return $self->{cmdline_hash}->{MXJ_CONFIG_FILE};
    }
}

#---------------#
sub mcm_started {
#---------------#
    my ($self) = @_;


    if ( $self->{cmdline_hash} && exists $self->{cmdline_hash}->{mcm} ) {
        return $self->{cmdline_hash}->{mcm};
    }

    return 0;
}

#-----------------#
sub mx_scripttype {
#-----------------#
    my ($self) = @_;

    return $self->{mx_scripttype};
}

#-----------------#
sub mx_scriptname {
#-----------------#
    my ($self) = @_;

    return $self->{mx_scriptname};
}

#----------#
sub entity {
#----------#
    my ($self) = @_;

    return $self->{entity};
}

#-----------#
sub runtype {
#-----------#
    my ($self) = @_;

    return $self->{runtype};
}

#--------#
sub name {
#--------#
    my ($self) = @_;

    return $self->{name};
}

#----------------#
sub mx_sessionid {
#----------------#
    my ($self, $mx_sessionid) = @_;

    $self->{mx_sessionid} = $mx_sessionid if $mx_sessionid;
    return $self->{mx_sessionid};
}

#----------#
sub mx_pid {
#----------#
    my ($self) = @_;

    return $self->{mx_pid};
}

#--------------#
sub mx_scanner {
#--------------#
    my ($self) = @_;

    return $self->{mx_scanner};
}

#--------------#
sub mx_noaudit {
#--------------#
    my ($self) = @_;

    return $self->{mx_noaudit};
}

#--------#
sub pcpu {
#--------#
    my ($self) = @_;

    return $self->{pcpu};
}

#--------#
sub pmem {
#--------#
    my ($self) = @_;

    return $self->{pmem};
}

#-------#
sub vsz {
#-------#
    my ($self) = @_;

    return $self->{vsz};
}

#-------#
sub rss {
#-------#
    my ($self) = @_;

    return $self->{rss};
}

#--------#
sub nlwp {
#--------#
    my ($self) = @_;

    return $self->{nlwp};
}

#-------#
sub nfh {
#-------#
    my ($self) = @_;

    return $self->{nfh};
}

#-----------#
sub cputime {
#-----------#
    my ($self) = @_;

    return $self->{cputime};
}

#
# This class method returns the full path to the pidfile, based on a descriptor
#
#-----------#
sub pidfile {
#-----------#
    my ($class, %args) = @_;

    my $config     = $args{config};
    my $descriptor = $args{descriptor};
    return $config->RUNDIR . '/' . $descriptor . '.pid';
}
#
# This method returns the full path to the pidfile
#---------------#
sub get_pidfile {
#---------------#
    my( $self ) = shift;
    return $self->{pidfile};
}
#
#
# Check if a pidfile already exists for a similar process, and if not, create one
#
#---------------#
sub set_pidfile {
#---------------#
    my ( $self, $identifier, $filename ) = @_;

  
    my $logger = $self->{logger}; 
    my $config = $self->{config};

    unless ( $identifier ) {
        $errstr = 'identifier is empty';
        $logger->error($errstr);
        return;
    }

    my $pidfile;
    if ( $filename ) {
        $pidfile = $filename;

        unless ( substr( $pidfile, 0, 1 ) eq '/' ) {
            $pidfile = $config->RUNDIR . '/' . $pidfile;
        }

        unless ( substr( $pidfile, -4 ) eq '.pid' ) {
            $pidfile .= '.pid';
        }
    }
    else {
        unless ( $self->{descriptor} ) {
            $errstr = 'descriptor is empty';
            $logger->error($errstr);
            return;
        }

        #
        # determine the name of the pidfile
        #
        $pidfile = Mx::Process->pidfile( descriptor => $self->{descriptor}, config => $config );
    }

    #
    # check if the pidfile already exists
    #
    if ( -f $pidfile ) {
        $logger->warn("pidfile $pidfile does already exist");

        #
        # read the pid from the file
        #
        my $pid;
        unless ( $pid = _read_pidfile($pidfile, $logger) ) {
            #
            # instead of crashing here, try to recover gracefully
            #
            unless ( _create_pidfile($pidfile, $self->{pid}, $logger) ) {
                return;
            }
            $self->{pidfile} = $pidfile;
            return 1;
        }

        $self->{pidfile_mtime} = (stat($pidfile))[9];

        #
        # check if a corresponding process exists
        #
        $logger->debug('checking if the process still exists');

        if ( my $process = Mx::Process->new( pid => $pid, config => $config, logger => $logger ) ) {
            #
            # the process does still exist, so check if the identifier appears in the cmdline
            #
            my $cmdline = $process->cmdline;

            if ( $cmdline =~ /$identifier/ ) {
                $logger->info("process $pid does still exists and its commandline contains $identifier");
                return;
            }
            else {
                $logger->info("a process with pid $pid exists but its commandline does not contain $identifier");

                unless ( $self->remove_pidfile($pidfile) ) {
                    return;
                }

                return $self->set_pidfile($identifier, $filename);
            }
        }
        else {
            $logger->debug("no process with pid $pid found");

            unless ( $self->remove_pidfile($pidfile) ) {
                return;
            }

            return $self->set_pidfile($identifier, $filename);
        }
    }
    else {
        $logger->debug("pidfile $pidfile does not exist yet");

        unless ( _create_pidfile($pidfile, $self->{pid}, $logger) ) {
            return;
        }

        $self->{pidfile}       = $pidfile;
        $self->{pidfile_mtime} = (stat($pidfile))[9];

        return 1;
    }
}

#------------------#
sub remove_pidfile {
#------------------#
    my ($self, $pidfile) = @_;

    $pidfile ||= $self->{pidfile};
    if ( $pidfile ) {
        unless ( unlink($pidfile) ) {
            $errstr = "cannot remove $pidfile: $!";
            $self->{logger}->error($errstr);
            return;
        }
        $self->{logger}->debug("pidfile $pidfile removed");
        return 1;
    }
    else {
        $errstr = "pidfile is empty";
        $self->{logger}->error($errstr);
        return;
    }
}

#--------------------#
sub _analyze_cmdline {
#--------------------#
    my ( $self ) = @_;


    my $logger     = $self->{logger};
    my $cmdline_h  = $self->{cmdline_hash}  || {};
    my $cmdline_a  = $self->{cmdline_array} || [];
    my $pattern    = $self->{pattern};

    if ( $pattern ) {
        my $cmdline = $self->cmdline;
        unless ( $cmdline =~ /$pattern/ ) { 
            $logger->warn("pattern ($pattern) is not present in cmdline ($cmdline)");
            return;
        }
    }

    if ( $cmdline_h->{dbname} && $cmdline_h->{dbname} eq $ENV{MXENV} ) {
        $self->{type} = $MXSESSION;

        $self->analyze_cmdline();
    }
    elsif ( $cmdline_h->{sched_js} ) {
        my $mx_scriptname = $self->{mx_scriptname} = ( $cmdline_a->[1] eq '-c' ) ? $cmdline_a->[2] : $cmdline_a->[1];

        if ( $mx_scriptname =~ /\.jobmanrc$/ ) {
            $self->{type} = $OTHER;
            return 1;
        }

        my $name = basename( $mx_scriptname );
        if ( $name eq 'cdirect.pl' ) {
            $self->{type} = $CDIRECT;
        }
        elsif ( $name =~ /^dm_.+\.pl$/ and $name ne 'dm_batch.pl' ) {
            $self->{type} = $DMSCRIPT;
        }
        else {
            $self->{type} = $MXSCRIPT;
        }

        $self->{project}  = $cmdline_h->{project};
        $self->{sched_js} = $cmdline_h->{sched_js};
        $self->{name}     = $cmdline_h->{name};

        $self->{cwd}     = _cwd( $self );
        $self->{logfile} = _open_file( $self, 3 );
    }
    elsif ( $cmdline_a->[0] eq 'mx' ) {
        $self->{type} = $MX_UNKNOWN;
    }
    elsif ( $cmdline_a->[0] eq 'java' or $cmdline_a->[0] =~ /\/java$/ ) {
        $self->{type} = $JAVA_UNKNOWN;
    }
    else {
        $self->{type} = $OTHER;
    }

    return 1;
}

#-------------------#
sub analyze_cmdline {
#-------------------#
    my ( $self ) = @_;


    my $cmdline_h;
    unless ( $cmdline_h = $self->{cmdline_hash} ) {
        $self->get_full_cmdline or return;
        $cmdline_h = $self->{cmdline_hash};
    }

    $self->{win_user}       = lc( $cmdline_h->{MXJ_CLIENT_LOGIN} );
    $self->{mx_client_host} = $cmdline_h->{MXJ_CLIENT_HOST};
    $self->{mx_client_ip}   = $cmdline_h->{MXJ_CLIENT_IPADDR};
    $self->{mx_nick}        = $cmdline_h->{MXJ_PROCESS_NICK_NAME};
    $self->{mx_scannernick} = $cmdline_h->{SCANNER_NICKNAME};
    $self->{mx_pid}         = $cmdline_h->{MXJ_PID};
    $self->{mx_user}        = $cmdline_h->{USER};
    $self->{mx_group}       = $cmdline_h->{GROUP};
    $self->{mx_desk}        = $cmdline_h->{DESK};
    $self->{app_user}       = $cmdline_h->{APPLICATION_USER};
    $self->{app_group}      = $cmdline_h->{APPLICATION_GROUP};
    $self->{app_desk}       = $cmdline_h->{APPLICATION_DESK};
    $self->{mx_scanner}     = $cmdline_h->{scanner};
    $self->{mx_noaudit}     = $cmdline_h->{noaudit};
    $self->{mx_scripttype}  = $cmdline_h->{scripttype};
    $self->{mx_scriptname}  = $cmdline_h->{scriptname};
    $self->{entity}         = $cmdline_h->{entity};
    $self->{runtype}        = $cmdline_h->{runtype};
    $self->{mx_sessionid}   = $cmdline_h->{sessionid};

    unless ( $self->{mx_scripttype} ) {
        if ( $self->{win_user} ) {
            $self->{mx_scripttype} = 'user session';
        }
        elsif ( $self->{mx_nick} =~ /^MXDEALSCAN/ ) {
            $self->{mx_scripttype} = 'scanner';
        }
        else {
            $self->{mx_scripttype} = 'server process';
        }
    }
}

#
# Called after background_run().
# If the process needs to run exclusively, the pidfile needs to be updated
# so that it contains the child pid
#
#------------------#
sub update_pidfile {
#------------------#
    my( $self, $child ) = @_;

    _create_pidfile( $self->get_pidfile(), $child, $self->{logger}, 'update' );
}

#-------------------#
sub _create_pidfile {
#-------------------#
    my ($pidfile, $pid, $logger, $update ) = @_;

        
    my $fh;
    unless ( $fh = IO::File->new( $pidfile, '>' ) ) {
        $errstr = "cannot create $pidfile: $!";
        $logger->error($errstr);
        return;
    } 

    printf $fh "%d\n", $pid;

    $fh->close();

    my $msg = $update ? 'updated' : 'created';
    $logger->debug("pidfile $pidfile $msg with pid $pid");

    return 1;
}

#-----------------#
sub _read_pidfile {
#-----------------#
    my ($pidfile, $logger) = @_;

    my $fh;
    unless ( $fh = IO::File->new( $pidfile, '<' ) ) {
        $errstr = "cannot open $pidfile: $!";
        $logger->error($errstr);
        return;
    } 
    my $pid;
    chomp( $pid = <$fh> );
    if ( $pid =~ /^\s*(\d+)\s*$/ ) {
        $pid = $1;
#        $logger->debug("pid in pidfile $pidfile is $pid");
    }
    else {
        $errstr = "pidfile $pidfile does not contain a valid pid ($pid)";
        $logger->error($errstr);
        return;
    }
    $fh->close();
    return $pid;
}

#
# Class method used to run an arbitrary command and capture its output.
#
# Arguments:
#
# command:   the command to run
# directory: if specified, the directory to first change to
# no_output: boolean indicating no output of the command should be logged
# timeout:   number of seconds before a command times out
# logger:    a Mx::Log object  
#
#-------#
sub run {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $command;
    unless ( $command = $args{command} ) {
        $logger->logdie('no command defined');
    }

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument (config)');
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie('config argument is not of type Mx::Config');
    }

    #
    # otherwise IPC::Cmd::run might behave strangely
    #
    $SIG{CHLD} = 'DEFAULT';

    my $currentdir;
    if ( $args{directory} ) {
        $currentdir = cwd();
        unless ( chdir($args{directory}) ) {
            $errstr = 'cannot cd to ' . $args{directory} . ": $!";
            $logger->error($errstr);
            return;
        }
        $logger->debug('changed to directory ', $args{directory});
    }

    #
    # make sure the library path is initialized correctly, otherwise terrible things will happen!!!!
    #
    $ENV{PATH}               = $config->PATH;
    $ENV{LD_LIBRARY_PATH}    = Mx::Util->cleanup_path( $ENV{LD_LIBRARY_PATH} . ':' . $config->LD_LIBRARY_PATH );
    $ENV{LD_LIBRARY_PATH_64} = $config->LD_LIBRARY_PATH_64;
    $ENV{MXWEBLOG}           = $args{mxweblog} if $args{mxweblog};

    $logger->debug("executing command: $command");

    if ( my $r = $args{apache_request} ) {
        my $apache_launcher = $config->BINDIR . '/apache_launcher.pl';

        $command = "$apache_launcher $command"; 

        #
        # split up the command in its executable and its arguments
        #
        my ($executable, @args) = split / /, $command; 

        #
        # replicate some environment variables for the spawned process
        #
        for my $key ( qw( MXCOMMON MXVERSION MXENV PATH LD_LIBRARY_PATH LD_LIBRARY_PATH_64 JAVA_HOME SYBASE SYBASE_OCS ) ) {
            my $value = $config->retrieve( $key );
            $r->subprocess_env->set( $key => $value );
        }

        #
        # also define the directory to change to in case the executable is apache_launcher.pl
        #
        $r->subprocess_env->set( APACHE_CHDIR   => $args{directory} );
        $r->subprocess_env->set( APACHE_PIDFILE => $args{pidfile}   ) if $args{pidfile};
        $r->subprocess_env->set( APACHE_LOGFILE => $args{logfile}   ) if $args{logfile};
        $r->subprocess_env->set( DISPLAY        => $args{display}   ) if $args{display};
        $r->subprocess_env->set( MXWEBLOG       => $args{mxweblog}  ) if $args{mxweblog};

        my $duration = time();
        my ($in_fh, $out_fh, $err_fh);
        unless ( ($in_fh, $out_fh, $err_fh) = $r->spawn_proc_prog($executable, \@args) ) {
            $errstr = "cannot start $executable from apache: $!";
            $logger->error($errstr);
            return;
        }
        $duration = time() - $duration;

        my $error_code = $?;

        my @stdout_buf = <$out_fh>;
        my @stderr_buf = <$err_fh>;

        my $pid;
        if ( @stdout_buf ) {
            $pid = shift @stdout_buf;
            chomp($pid);
            $logger->debug("pid was $pid");
        }

        my $output = join "", @stdout_buf;

        $logger->debug("command output:\n@stdout_buf")       if ( @stdout_buf && ! $args{no_output} );
        $logger->error("command error output:\n@stderr_buf") if @stderr_buf;

        if ( $currentdir ) {
            chdir($currentdir);
        }

        if ( wantarray() ) {
            return(1, $error_code, $output, $pid, $duration);
        }
        else {
            return 1;
        }
    } else {
        if ( $command =~ /;/ ) {
            #
            # if the command contains semicolons we have to wrap it again via a shell, and we cannot return the correct pid
            #
            $command = 'echo $$; exec /bin/sh -c "' . $command . '"';
        }
        else {
            $command = 'echo $$; exec ' . $command;
        }

        my $timeout = $args{timeout} || 0;

        $logger->debug("timeout specified of $timeout seconds") if $timeout;

        my $db_audit = $args{db_audit};
        $db_audit->close if $db_audit;

        my $duration = time();
        my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = IPC::Cmd::run( command => $command, verbose => 0, timeout => $timeout );
        $duration = time() - $duration;

        $db_audit->reopen if $db_audit;

        my $pid;
        if ( @$full_buf ) {
            $pid = shift @$full_buf;
            chomp($pid);
            $logger->debug("pid was $pid");
        }

        my $output = join "", @$full_buf;
        if ( $args{no_output} ) {
            my $error_output = join "", @$stderr_buf;
            $logger->debug("command error output:\n$error_output") if $error_output;
        }
        else {
            $logger->debug("command output:\n$output") if $output;
        }

        if ( $success ) {
            $logger->debug('command succeeded');
        }
        else {
            $logger->warn("command failed, error message: $error_message");
            if ( $error_message =~ /IPC::Cmd::TimeOut/ ) {
                $output .= "\n" . $error_message . "\n";
            }
        }

        if ( $currentdir ) {
            chdir($currentdir);
        }

        if ( wantarray() ) {
            return ($success, $error_message, $output, $pid, $duration);
        }
        else {
            return $success;
        }
    }
}

#
# Class method used to run an arbitrary command in the background and capture its output.
# The forked process is returned.
# Or, if a max_runtime is specified, the forked process executing the command and all its
# children are killed when its time has run out.
#
# Arguments:
#
# command:       command to execute
#  or
# statement, sybase: statement to execute
#
# directory:     if specified, the directory to first change to
# max_runtime:   maximum runtime in seconds (optional)
# poll_interval: polling interval to see if the command is still running (optional)
# ignore_child:  reap children automatically to avoid zombies
# logger, config
#
#------------------#
sub background_run {
#------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $tag = $args{tag} || '';

    my $command; my $statement; my $sybase;
    if ( $command = $args{command} ) {
        $logger->debug("executing background command: $command") unless $args{quiet};
    }
    elsif ( ( $statement = $args{statement} ) && ( $sybase = $args{sybase} ) ) {
        unless ( $args{quiet} ) {
            $logger->debug("executing background SQL statement:");
            $logger->debug("[$statement]");
        }
    }
    else {
        $logger->logdie('no command or statement defined');
    }

    my $reader; my $writer;
    pipe $reader, $writer;

    #
    # check config argument
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument (config)');
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie('config argument is not of type Mx::Config');
    }

    my $tagfile;
    if ( $tag ) {
        $tagfile = $config->RUNDIR . '/' . $tag;
        if ( -e $tagfile ) {
            if ( unlink $tagfile ) {
                $logger->info("dependency tag $tag cleaned up");
            }
            else {
                $logger->logdie("dependency tag $tag not cleaned up: $!");
            }
        }
    }

    my ($max_runtime, $poll_interval);
    if ( $max_runtime = $args{max_runtime} ) {
        $logger->debug("maximum runtime is $max_runtime seconds") unless $args{quiet};
        $poll_interval = $args{poll_interval} || DEFAULT_POLL_INTERVAL;
    }

    my $pid = undef;
    my $process;

    #
    # make sure the library path is initialized correctly, otherwise terrible things will happen!!!!
    #
    $ENV{PATH}            = $config->PATH;
    $ENV{LD_LIBRARY_PATH} = Mx::Util->cleanup_path( $ENV{LD_LIBRARY_PATH} . ':' . $config->LD_LIBRARY_PATH );

    if ( my $envlist = $args{env} ) {
        while ( my( $key, $value ) = each %{$envlist} ) {
            $ENV{$key} = $value;
            $logger->debug("environment variable $key set to $value");
        }
    }

    #
    # if the CHLD signal is not ignored, a kill of the forked process will result in a zombie
    #
    $SIG{CHLD} = 'IGNORE' if $args{ignore_child};

    if ( $pid = fork ) {
        #
        # I'm the parent
        #
        $logger->debug("new child process forked (pid $pid)") unless $args{quiet};

        while ( ! $process ) {
            $process = Mx::Process->new( pid => $pid, ppid => $$, uid => $<, light => 1, logger => $logger, config => $config );
            sleep 1;
        }

        $process->{tag} = $tag;

        close( $writer );
        $process->{_reader} = $reader;

        if ( $max_runtime ) {
            my $starttime = time();
            my $max_time  = time() + $max_runtime;
            while ( time() < $max_time ) {
                #
                # wait for any children to die
                #
                while ( my $rv = waitpid( $pid, &WNOHANG ) ) {
                    if ( $rv == $pid  ) {
                        my $exitvalue = $? >> 8;
                        my $elapsed_time = time() - $starttime;
                        $logger->debug("process ended after $elapsed_time seconds with exitvalue $exitvalue") unless $args{quiet};
                        return $exitvalue;
                    }
                }
                sleep($poll_interval);
            }

            $logger->warn("maximum runtime ($max_runtime seconds) exceeded, killing process $pid and all its children");
            $process->kill( recursive => 1 );
            return;
        }
        else {
            return $process;
        }
    }
    elsif ( defined $pid ) {
        #
        # I'm the child
        #
        if ( $args{delay} ) {
            $logger->debug("sleeping for a delay of " . $args{delay} . " seconds") unless $args{quiet};
            sleep $args{delay};
        }
        #
        # become a session leader
        # 
        setsid();

        if ( $args{directory} ) {
            unless ( chdir($args{directory}) ) {
                $errstr = 'cannot cd to ' . $args{directory} . ": $!";
                $logger->error($errstr);
                exit 1;
            }
            $logger->debug('changed to directory ', $args{directory}) unless $args{quiet};
        }

        if ( my $file = $args{output} ) {
            if ( open STDOUT, ">> $file" ) {
                $logger->debug("STDOUT redirected to $file") unless $args{quiet};
            }
            else {
                $logger->error("cannot redirect STDOUT to $file: $!");
            }
            if ( open STDERR, ">> $file" ) {
                $logger->debug("STDERR redirected to $file") unless $args{quiet};
            }
            else {
                $logger->error("cannot redirect STDERR to $file: $!");
            }
        }

        if ( $command && ( my $mxweblog = $ENV{MXWEBLOG} ) ) {
            $command = "MXWEBLOG=$mxweblog;export MXWEBLOG;$command";
        }
    
        if ( my $dependencies = $args{dependencies} ) {
            unless ( ref( $dependencies ) eq 'ARRAY' ) {
                $logger->logdie("argument dependencies is not an array ref");
            }

            my @dependencies = @{$dependencies};
            $logger->info("background process $tag: waiting for dependencies: @dependencies");

            my $poll_interval = $args{poll_interval} || 5;

            my $rundir = $config->RUNDIR;

            my %dependencies = ();
            foreach my $dependency ( @dependencies ) {
                $dependencies{ $rundir . '/' . $dependency } = 0;
            }

MAIN:       while ( 1 ) {
                keys %dependencies;

                while ( my ( $file, $present ) = each %dependencies ) {
                    next if $present;

                    unless ( -e $file ) {
                        sleep $poll_interval;
                        next MAIN;
                    }

                    $dependencies{ $file } = 1;
                }

                last;
            }

            $logger->info("background process $tag: all dependencies fulfilled: @dependencies");
        }

        close ( $reader );

        my $semaphore;
        if ( ( $semaphore = $args{semaphore} ) && ( $tag || $statement ) ) {
            $semaphore->acquire( max_retries => -1, poll_interval => 5, quiet => 1 );
        }

        my $duration; my $nr_rows = 0; my $exitvalue = 0; my $output = '';
        if ( $command ) {
            if ( ! $tag ) {
                my @command = parse_line( ' ', 0, $command );

                unless ( exec( @command ) ) {
                    $logger->logdie("cannot execute '$command': $!");
                }
            }
            
            $duration = time();
            my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = IPC::Cmd::run( command => $command, verbose => 0 );
            $duration = time() - $duration;

            if ( @$full_buf ) {
                $output = join '', @$full_buf;
            }

            if ( $success ) {
                $logger->info("command succeeded (tag: $tag - duration: $duration seconds)");
            }
            else {
                $logger->error("command failed (tag: $tag -  error message: $error_message)");
                $exitvalue = 1;
            }
        }
        else {
            my $do_close = 0;
            unless ( $sybase->is_open ) {
                $sybase->open( private => 1 );
                $do_close = 1;
            }

            $duration = time();
            if ( $statement =~ /\ngo\n/ ) {
                $nr_rows = $sybase->composite_do( %args );
            }
            else {
                $nr_rows = $sybase->do( %args );
            }
            $duration = time() - $duration;

            $sybase->close() if $do_close;

            if ( $nr_rows eq '0E0' or $nr_rows != 0 ) {
                $logger->info("statement succeeded (tag: $tag - number of rows: $nr_rows - duration: $duration seconds)");
            }
            else {
                $logger->error("statement failed (tag: $tag)");
                $exitvalue = 1;
            }
        }

        if ( $semaphore ) {
            $semaphore->release();
        }

        printf $writer "%s:%s:%s:%s\n", $tag, $duration, $nr_rows, $output;

        close( $writer );

        exit $exitvalue if $exitvalue;

        if ( $tagfile ) {
            if ( open FH, ">$tagfile" ) {
                close( FH );
                $logger->info("dependency tag $tag created");
            }
            else {
                $logger->logdie("dependency tag $tag not created: $!");
            }
        }

        exit 0;
    }
    else {
        $logger->logdie("cannot fork: $!");
    }
}

#-------------------#
sub _process_reader {
#-------------------#
    my ( $self ) = @_;


    if ( my $fh = $self->{_reader} ) {
        my $info = '';
        while ( <$fh> ) {
            $info .= $_;
        }
        close( $fh );

        $self->{_reader} = undef;

        ( $self->{tag}, $self->{duration}, $self->{nr_rows}, $self->{output} ) = split ( /:/, $info, 4 );
    }
}

#----------#
sub output {
#----------#
    my ( $self ) = @_;


    $self->_process_reader();

    return $self->{output};
}

#-----------#
sub nr_rows {
#-----------#
    my ( $self ) = @_;


    $self->_process_reader();

    return $self->{nr_rows};
}

#------------#
sub duration {
#------------#
    my ( $self ) = @_;


    $self->_process_reader();

    return $self->{duration};
}

#-------#
sub tag {
#-------#
    my ( $self ) = @_;


    $self->_process_reader();

    return $self->{tag};
}

#-------------#
sub exitvalue {
#-------------#
    my ( $self ) = @_;


    return $self->{exitvalue};
}

#------------#
sub java_xms {
#------------#
    my ( $self ) = @_;


    my $xms = ''; my $xmx = '';
    foreach my $item ( @{$self->{cmdline_array}} ) {
        if ( my ( $xm_type, $xm_value, $xm_unit ) = $item =~ /^-Xm([sx])(\d+)([mMgG]?)$/ ) {
            $xm_value *= 1024 if lc($xm_unit) eq 'm';
            $xm_value *= 1024 * 1024 if lc($xm_unit) eq 'g';
            if ( $xm_type eq 's' ) {
                $xms = $xm_value;
            } 
            else {
                $xmx = $xm_value;
            }
        }
    }

    return ( $xms, $xmx );
}

#---------------#
sub session_map {
#---------------#
    my ( $class, %args ) = @_;


    my %sessions = ();
    my $logger = $args{logger} or croak 'no logger defined.';
    my $config;
    unless ( $config = $args{config} ) {
        $logger->fail('missing argument (config)');
    }

    my $session_map = $config->retrieve('SESSION_MAP'); 

    my $fh;
    unless ( $fh = IO::File->new( $session_map ) ) {
        $logger->error("cannot locate session map ($session_map)");
        return ();
    }

    while ( my $entry = <$fh> ) {
        if ( $entry =~ /^(\d+):(\w+)(\.\w+\.\w+\.\w+)?:(\w+):([\w-]+)$/ ) {
            $sessions{"$1:$2"} = { user => $4, group => $5 };
        }
    }

    $fh->close();

    return %sessions;
}

#--------------------#
sub analyze_corefile {
#--------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->fail('missing argument (config)');
    }

    my $core_file;
    unless ( $core_file = $args{file} ) {
        $logger->fail('missing argument (file)');
    }

    my $id;
    unless ( $id = $args{id} ) {
        $logger->fail('missing argument (id)');
    }

    unless ( -f $core_file ) {
        $logger->error("cannot locate $core_file");
        return;
    }

    my $timestamp = (stat( $core_file ))[9];
    my $size      = -s $core_file;

    if ( $size == 0 ) {
        $logger->error("$core_file is empty (filesystem full?)");
        return;
    }

    my $crashdir = $config->CRASHDIR;
    my $mxuser   = $config->MXUSER;
    my $mxgroup  = $config->MXGROUP;

    if ( system("/usr/bin/pb chown $mxuser:$mxgroup $core_file") ) {
        $logger->error("cannot change ownership of $core_file: $!");
        return;
    }

    my $target_file = $core_file . '.' . $id;
    unless ( rename $core_file, $target_file ) {
        $logger->error("cannot rename $core_file to $target_file: $!");
        return;
    }
    $core_file = $target_file;

    my $pstack_file = $config->COREDIR . '/' . $id . '.pstack';
    my $pmap_file   = $config->COREDIR . '/' . $id . '.pmap';

    my $fh_pstack;
    unless ( $fh_pstack = IO::File->new( $pstack_file, '>' ) ) {
        $logger->error("cannot open $pstack_file: $!");
        return;
    }


    my $command = "/usr/bin/pstack $core_file";

    my $tooldir = $config->retrieve('TOOLDIR');
    if ( -f "$tooldir/c++filt" ) {
        $command .= "|$tooldir/c++filt";
    }

    unless ( open CMD, "$command |" ) {
        $logger->error("pstack of $core_file failed: $!");
        return;
    }

    my $function;
    while ( my $line = <CMD> ) {
        if ( $line =~ /^ --- called from signal handler with signal /
          or $line =~ /^ \w{8} __cxa_rethrow /
          or $line =~ /^ \w{8} __cxa_call_unexpected / ) {
            print $fh_pstack $line;

            while ( my $next_line = <CMD> ) {
                print $fh_pstack $next_line;

                if ( $next_line =~ /^ \w{8} (\w+) / ) {
                    if ( $1 ne '????????' ) {
                        $function = $1;
                        last;
                    } 
                }
            }

            last;
        }

        print $fh_pstack $line;
    }

    if ( $function ) {
        $logger->info("last identifiable function in stack trace: $function");
    }
    else {
        $logger->warn("no last identifiable function in stack trace");
    }

    while ( my $line = <CMD> ) {
        print $fh_pstack $line;
    }

    close(CMD);
    $fh_pstack->close;

    my $fh_pmap;
    unless ( $fh_pmap = IO::File->new( $pmap_file, '>' ) ) {
        $logger->error("cannot open $pmap_file: $!");
        return;
    }

    unless ( open CMD, "/usr/bin/pmap $core_file |" ) {
        $logger->error("pmap of $core_file failed: $!");
        return;
    }

    while ( my $line = <CMD> ) {
        print $fh_pmap $line;
    }

    close(CMD);
    $fh_pmap->close;

    return ( $core_file, $pstack_file, $pmap_file, $size, $timestamp, $function );
}

#------------------#
sub analyze_gcfile {
#------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->fail('missing argument (config)');
    }

    my $gcfile;
    unless ( $gcfile = $args{file} ) {
        $logger->fail('missing argument (file)');
    }

    my $fh;
    unless ( $fh = IO::File->new( $gcfile, '<' ) ) {
        $logger->error("cannot open $gcfile: $!");
        return;
    }

    my @results = ();

    while ( my $line = <$fh> ) {
        chomp($line);

        if ( $line =~ /^(\d+\.\d+): \[(.+) (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs]/ ) {
            push @results, {
              timestamp  => $1,
              full       => ( $2 eq "Full GC" ) ? 1 : 0,
              start_size => $3,
              end_size   => $4,
              total_size => $5, 
              duration   => $6
            }
        }
    }

    $fh->close();

    return @results;
}

#-----------#
sub last_gc {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $gcfile = $config->retrieve('GCLOGDIR') . '/' . $self->{descriptor} . '.gc';

    my $fh;
    unless ( $fh = IO::File->new( $gcfile, '<' ) ) {
        return;
    }

    my %result = ();
    my $total_gcs = 0;
    my $total_full_gcs = 0;

    my $line;
    while ( <$fh> ) {
        $line = $_;
        $total_gcs++;
        $total_full_gcs++ if $line =~ /Full GC/;
    }

    if ( $line =~ /^(\d+\.\d+): \[(.+) (\d+)K->(\d+)K\((\d+)K\), (\d+\.\d+) secs]/ ) {
        %result = ( 
          timestamp      => $1,
          full           => ( $2 eq "Full GC" ) ? 1 : 0,
          start_size     => $3,
          end_size       => $4,
          total_size     => $5, 
          duration       => $6,
          total_gcs      => $total_gcs,
          total_full_gcs => $total_full_gcs,
        );
    }

    $fh->close();

    return %result;
}

#-----------------------------#
sub prepare_for_serialization {
#-----------------------------#
    my ( $self, %args ) = @_;
 
 
    $self->{logger}        = undef;
    $self->{config}        = undef;
    if ( $args{exclude_cmdline} ) {
        $self->{cmdline_hash}  = undef;
        $self->{cmdline_array} = undef;
    }
}

#-------------------------------#
sub unprepare_for_serialization {
#-------------------------------#
    my ( $self, %args ) = @_;
 
 
    $self->{logger} = $args{logger};
    $self->{config} = $args{config};
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;


    if ( $self->{type} == $MXSESSION ) {
        my $mx_sessionid = $self->{mx_sessionid} || 0;

        my $mmsfile = $self->{config}->MMSDIR . '/' . $mx_sessionid . '.txt';
        my $mms = ( -f $mmsfile ) ? 1 : 0;

        return {
          0  => $self->{pid},
          1  => $self->{hostname},
          2  => $self->{mx_scripttype},
          3  => $self->{mx_nick},
          4  => $self->{mx_scriptname},
          5  => $self->{full_name},
          6  => $self->{mx_user},
          7  => $self->{mx_group},
          8  => Mx::Util->convert_time( $self->{starttime} ),
          9  => $self->{pcpu},
          10 => $self->{pmem},
          11 => Mx::Util->separate_thousands( $self->{vsz} ),
          12 => Mx::Util->separate_thousands( $self->{rss} ),
          13 => Mx::Util->separate_thousands( $self->{cputime} ),
          14 => $self->{mx_sessionid},
          15 => scalar( Mx::Util->convert_seconds( time() - $self->{starttime} ) ),
          16 => $self->{win_user},
          17 => $self->{session_count},
          18 => $self->{mx_client_host},
          19 => $self->{mx_client_ip},
          20 => $self->{mx_pid},
          21 => $mms,
          DT_RowId => $mx_sessionid . '|' . $self->{hostname} . '|' . $self->{pid} . '|' . $self->{mx_pid}
        };
    }
    elsif ( $self->{type} == $MXSCRIPT || $self->{type} == $DMSCRIPT ) {
        my $path = $self->{mx_scriptname};

        if ( substr( $path, 0, 2 ) eq './' ) {
            substr( $path, 0, 1 ) = $self->{cwd};
        }
        elsif ( substr( $path, 0, 1 ) ne '/' ) {
            $path = $self->{config}->PROJECT_DIR . '/' . $self->{project} . '/bin/' . basename( $path );
        }

        return {
          0  => $self->{pid},
          1  => $self->{hostname},
          2  => basename( $self->{mx_scriptname} ),
          3  => $self->{project},
          4  => $self->{sched_js},
          5  => Mx::Util->convert_time( $self->{starttime} ),
          6  => $self->{pcpu},
          7  => $self->{pmem},
          8  => Mx::Util->separate_thousands( $self->{vsz} ),
          9  => Mx::Util->separate_thousands( $self->{rss} ),
          10 => Mx::Util->separate_thousands( $self->{cputime} ),
          DT_RowId => $self->{hostname} . '|' . $self->{pid} . '|' . $path . '|' . $self->{logfile}
        };
    }
}

sub REAPER { 1 until waitpid(-1 , WNOHANG) == -1 };

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

