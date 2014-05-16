package Mx::System;
 
use strict;
use warnings;

use Mx::Util;
use Carp;

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    $self->{config} = $args{config};

    bless $self, $class;
}

#--------------#
sub os_version {
#--------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    my $release_file; my $extra_command;
    if ( -e '/etc/release' ) {
        $release_file = '/etc/release';
    }
    elsif ( -e '/etc/redhat-release' ) {
        $release_file = '/etc/redhat-release';
        $extra_command = '/bin/uname -r';
    }
    else {
        $logger->error("cannot find a release file");
        return;
    }

    unless ( open FH, $release_file ) {
        $logger->error("cannot open $release_file: $!");
        return '';
    }

    my $os_version = <FH>;

    close(FH);

    $os_version =~ s/^\s+//;
    $os_version =~ s/\s+$//;

    if ( $extra_command ) {
        unless ( open CMD, "$extra_command|" ) {
            $logger->error("cannot execute $extra_command: $!");
            return $os_version;
        } 

        my $kernel_version = <CMD>;

        close(CMD);

        chomp($kernel_version);

        $os_version .= " $kernel_version";
    }

    return $os_version;
}

#------------------#
sub aix_os_version {
#------------------#
    my ( $self, $server ) = @_;


    my $logger    = $self->{logger};
    my $ssh_login = $self->{config}->SYB_SSH_LOGIN;

    unless ( open CMD, "ssh -l $ssh_login $server oslevel|" ) {
        $logger->error("cannot use oslevel: $!");
        return '';
    }

    my $os_version = <CMD>;

    close(CMD);

    return '' unless $os_version;

    chomp($os_version);

    return 'AIX ' . $os_version;
}

#----------------#
sub java_version {
#----------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    my $java_home = $self->{config}->retrieve('JAVA_HOME');
    my $java_bin  = $java_home . '/bin/java';

    unless ( -f $java_bin ) {
        $logger->error("cannot locate java binary");
        return '';
    }

    unless ( open CMD, "$java_bin -version 2>&1|" ) {
        $logger->error("cannot determine java version: $!");
        return '';
    }

    <CMD>;
    my $java_version = <CMD>;

    close(CMD);

    chomp($java_version);

    return $java_version;
}

#-------------------#
sub hostname_and_ip {
#-------------------#
    my ( $self, $hostname ) = @_;


    my $logger = $self->{logger};

    my $short_hostname = $hostname || Mx::Util->hostname();

    my $host_binary;
    if ( -e '/usr/sbin/host' ) {
        $host_binary = '/usr/sbin/host';
    }
    elsif ( -e '/usr/bin/host' ) {
        $host_binary = '/usr/bin/host';
    }
    else {
        $logger->error("cannot find host command");
        return '';
    }

    unless ( open CMD, "$host_binary $short_hostname|" ) {
        $logger->error("cannot use /usr/sbin/host: $!");
        return '';
    }

    my $line = <CMD>;

    close(CMD);

    my $ip;
    if ( $line =~ /^(\S+) has address (\S+)$/ ) {
        $hostname = $1;
        $ip       = $2;
    }

    return ($hostname, $ip);
}

#------------#
sub username {
#------------#
    my ( $self ) = @_;


    return ( getpwuid( $< ) )[0];
}

#------------#
sub platform {
#------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/sys/class/dmi/id/sys_vendor' ) {
        unless ( open FH, '/sys/class/dmi/id/sys_vendor' ) {
            $logger->error("cannot open /sys/class/dmi/id/sys_vendor: $!");
            return '';
        }

        my $platform = <FH>;

        close(FH); 

        chomp($platform);

        return $platform;
    }

    unless ( open CMD, "/usr/sbin/prtdiag|" ) {
        $logger->error("cannot use /usr/sbin/prtdiag: $!");
        return '';
    }

    my $platform;
    while ( my $line = <CMD> ) {
        if ( $line =~ /^System Configuration: (.+)$/ ) {
            $platform = $1;
            last;
        } 
    }

    close(CMD);

    return $platform;
}

#-----------#
sub nr_cpus {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/proc/cpuinfo' ) {
        unless ( open FH, '/proc/cpuinfo' ) {
            $logger->error("cannot open /proc/cpuinfo: $!");
            return '';
        }

        my $nr_cpus = 0;
        while ( <FH> ) {
            $nr_cpus++ if /^processor\s+: \d+$/; 
        }

        close(FH);

        return $nr_cpus;
    }

    unless ( open CMD, "/usr/sbin/psrinfo -p|" ) {
        $logger->error("cannot use /usr/sbin/psrinfo: $!");
        return '';
    }

    my $nr_cpus = <CMD>;

    close(CMD);

    chomp($nr_cpus);

    return $nr_cpus;
}

#------------#
sub nr_cores {
#------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/proc/cpuinfo' ) {
        unless ( open FH, '/proc/cpuinfo' ) {
            $logger->error("cannot open /proc/cpuinfo: $!");
            return '';
        }

        my $nr_cores = 0;
        while ( <FH> ) {
            $nr_cores++ if /^processor\s+: \d+$/; 
        }

        close(FH);

        return $nr_cores;
    }

    unless ( open CMD, "/usr/sbin/psrinfo|" ) {
        $logger->error("cannot use /usr/sbin/psrinfo: $!");
        return '';
    }

    my $nr_cores = 0;
    while ( <CMD> ) {
        $nr_cores++;
    }

    close(CMD);

    return $nr_cores;
}

#------------#
sub cpu_type {
#------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/proc/cpuinfo' ) {
        unless ( open FH, '/proc/cpuinfo' ) {
            $logger->error("cannot open /proc/cpuinfo: $!");
            return '';
        }

        my $cpu_type; 
        while ( <FH> ) {
            if ( /^model name\s+: (.+)$/ ) {
                $cpu_type = $1;
                last;
            }
        }

        close(FH);

        return $cpu_type;
    }

    unless ( open CMD, "/usr/sbin/psrinfo -vp|" ) {
        $logger->error("cannot use /usr/sbin/psrinfo: $!");
        return '';
    }

    <CMD>;
    my $cpu_type = <CMD>;
    $cpu_type .= <CMD>;  

    close(CMD);

    chomp($cpu_type);

    return $cpu_type;
}

#-------------#
sub memory_gb {
#-------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/proc/meminfo' ) {
        unless ( open FH, '/proc/meminfo' ) {
            $logger->error("cannot open /proc/meminfo: $!");
            return '';
        }

        my $size; 
        while ( <FH> ) {
            if ( /^MemTotal:\s+(\d+) kB$/ ) {
                $size = $1;
                last;
            }
        }

        close(FH);

        return sprintf "%.2f", $size / ( 1024 * 1024 );
    }

    unless ( open CMD, "/usr/sbin/prtconf|" ) {
        $logger->error("cannot use /usr/sbin/prtconf: $!");
        return '';
    }

    my $size;
    while ( my $line = <CMD> ) {
        if ( $line =~ /^Memory size: (\d+) Megabytes/ ) {
            $size = $1;
            last;
        } 
    }

    close(CMD);

    sprintf "%.2f", $size / 1024;
}

#-----------#
sub swap_gb {
#-----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    if ( -e '/proc/meminfo' ) {
        unless ( open FH, '/proc/meminfo' ) {
            $logger->error("cannot open /proc/meminfo: $!");
            return '';
        }

        my $size; 
        while ( <FH> ) {
            if ( /^SwapTotal:\s+(\d+) kB$/ ) {
                $size = $1;
                last;
            }
        }

        close(FH);

        return sprintf "%.2f", $size / ( 1024 * 1024 );
    }

    unless ( open CMD, "/usr/sbin/swap -l|" ) {
        $logger->error("cannot use /usr/sbin/swap: $!");
        return '';
    }

    my $size;
    while ( my $line = <CMD> ) {
        if ( $line =~ /\s+(\d+)\s+\d+$/ ) {
            $size += $1;
        } 
    }

    close(CMD);

    sprintf "%.2f", $size / (2 * 1024 * 1024);
}

#--------#
sub date {
#--------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    unless ( open CMD, "/bin/date '+%Y%m%d %H:%M:%S'|" ) {
        $logger->error("cannot use /bin/date: $!");
        return '';
    }

    my $date = <CMD>;

    close(CMD);

    chomp($date);

    return $date;
}

#------------#
sub aix_date {
#------------#
    my ( $self, $server ) = @_;


    my $logger    = $self->{logger};
    my $ssh_login = $self->{config}->SYB_SSH_LOGIN;

    unless ( open CMD, "ssh -l $ssh_login $server date \\'+%Y%m%d %H:%M:%S\\'|" ) {
        $logger->error("cannot use /usr/bin/date: $!");
        return '';
    }

    my $date = <CMD>;

    close(CMD);

    return '' unless $date;

    chomp($date);

    return $date;
}

#----------#
sub uptime {
#----------#
    my ( $self ) = @_;


    my $logger = $self->{logger};

    unless ( open CMD, "/usr/bin/who -b|" ) {
        $logger->error("cannot use /usr/bin/who: $!");
        return '';
    }

    my $line = <CMD>;

    close(CMD);

    my $uptime;
    if ( $line =~ /system boot (.+)$/ ) {
        $uptime = $1;
    } 

    return $uptime;
}

#--------------#
sub aix_uptime {
#--------------#
    my ( $self, $server ) = @_;


    my $logger    = $self->{logger};
    my $ssh_login = $self->{config}->SYB_SSH_LOGIN;

    unless ( open CMD, "ssh -l $ssh_login $server who -b|" ) {
        $logger->error("cannot use /usr/bin/who: $!");
        return '';
    }

    my $line = <CMD>;

    close(CMD);

    return '' unless $line;

    my $uptime;
    if ( $line =~ /system boot (.+)$/ ) {
        $uptime = $1;
    } 

    return $uptime;
}

#----------------#
sub aix_lparstat {
#----------------#
    my ( $self, $server ) = @_;


    my $logger    = $self->{logger};
    my $ssh_login = $self->{config}->SYB_SSH_LOGIN;

    unless ( open CMD, "ssh -l $ssh_login $server lparstat -i|" ) {
        $logger->error("cannot open lparstat: $!");
        return '';
    }

    my %lpar = ();
    while ( my $line = <CMD> ) {
        if ( $line =~ /^Type\s+:\s+(.+)/ ) {
            $lpar{lpar_type} = $1;
        }
        elsif ( $line =~ /^Entitled Capacity\s+:\s+(.+)/ ) {
            $lpar{entitlement} = $1;
        }
        elsif ( $line =~ /^Online Virtual CPUs\s+:\s+(\d+)/ ) {
            $lpar{virtual_cpus} = $1;
        }
        elsif ( $line =~ /^Online Memory\s+:\s+(\d+) MB/ ) {
            $lpar{memory_gb} = sprintf "%.2f", $1 / 1024;
        }
    }

    close(CMD);

    return %lpar;
}

#--------#
sub info {
#--------#
    my ( $self, %args ) = @_;


    my %info = (
      platform   => $self->platform(),
      os_version => $self->os_version(),
	  username   => $self->username(),
      nr_cpus    => $self->nr_cpus(),
      nr_cores   => $self->nr_cores(),
      cpu_type   => $self->cpu_type(),
      memory_gb  => $self->memory_gb(),
      swap_gb    => $self->swap_gb(),
      date       => $self->date(),
      uptime     => $self->uptime(),
    );

    ( $info{hostname}, $info{ip} ) = $self->hostname_and_ip();

    return \%info;
}

#------------#
sub aix_info {
#------------#
    my ( $self, $server ) = @_;


    my $logger = $self->{logger};

    my %info = $self->aix_lparstat( $server );

    $info{os_version} = $self->aix_os_version( $server );
    $info{date}       = $self->aix_date( $server );
    $info{uptime}     = $self->aix_uptime( $server );
    ( $info{hostname}, $info{ip} ) = $self->hostname_and_ip( $server );

    return %info;
}

1;
