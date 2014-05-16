package Mx::TWS::Job;

use strict;
use warnings;

use IO::File;
use Fcntl qw( :seek );
use File::Basename;
use Time::Local;
use Carp;

use Mx::Log;
use Mx::DBaudit;


#
# Members:
#
# id
# tws_job_id
# mode
# name
# jobstream
# username
# workstation
# plantime
# command
# + remote
# + instance
# + nowait
# + project
# + scriptname
# starttime
# endtime
# exitcode
# stdout
# plan_date
# tws_date
# business_date
# job_nr
# 
# logfile
# logfile_size
# logfile_pos
#

my %JOBCACHE = ();

#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $args{logger} or croak 'no logger defined.';
    $self->{logger} = $logger;

    my $config;
    unless ( $config = $self->{config} = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $db_audit;
    unless ( $db_audit = $self->{db_audit} = $args{db_audit} ) {
        $logger->logdie("missing argument (db_audit)");
    }

    #
    # check the arguments
    #
    my @required_args = qw(mode name jobstream username workstation plantime plan_date command job_nr starttime tws_date logfile stdout_begun);
    foreach my $arg (@required_args) {
        unless ( $self->{$arg} = $args{$arg} ) {
            $logger->logdie("missing argument ($arg)");
        }
    }

    $self->{logfile_size} = $args{logfile_size};
    $self->{logfile_pos}  = $args{logfile_pos};
    $self->{endtime}      = $args{endtime};
    $self->{exitcode}     = $args{exitcode};
    $self->{stdout}       = $args{stdout};

    bless $self, $class;

    my $tws_job_id = $self->_retrieve_tws_job_id;

    $self->{id} = $db_audit->record_tws_execution( tws_job_id => $tws_job_id, mode => $self->{mode}, starttime => $self->{starttime}, plan_date => $self->{plan_date}, tws_date => $self->{tws_date}, job_nr => $self->{job_nr} );

    if ( $self->{endtime} ) {
        $db_audit->update_tws_execution( endtime => $self->{endtime}, exitcode => $self->{exitcode}, stdout => ( $self->{stdout} ) ? 'Y' : 'N', id => $self->{id} );

        $self->dump_stdout;
    }

    return $self;
}

#----------#
sub update {
#----------#
    my ( $self, %args ) = @_;


    return 1 if $self->{endtime};

    return if -s $self->{logfile} == $self->{logfile_size};

    if ( $self->reparse_logfile ) {
        $self->{db_audit}->update_tws_execution( endtime => $self->{endtime}, exitcode => $self->{exitcode}, stdout => ( $self->{stdout} ) ? 'Y' : 'N', id => $self->{id} );

        $self->dump_stdout;

        return 1;
    }

    return;
}

#---------------#
sub dump_stdout {
#---------------#
    my ( $self ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    if ( $self->{stdout} ) {
        my $dumpfile = $config->TWSDIR . '/' . $self->{id} . '.stdout';

        my $fh;
        unless ( $fh = IO::File->new( $dumpfile, '>' ) ) {
            $logger->logdie("cannot open $dumpfile: $!");
        }

        print $fh $self->{stdout};

        $fh->close;
    }
}

#------------------------#
sub _retrieve_tws_job_id {
#------------------------#
    my ( $self ) = @_;


    my $logger      = $self->{logger};
    my $db_audit    = $self->{db_audit};
    my $name        = $self->{name};
    my $jobstream   = $self->{jobstream};
    my $username    = $self->{username};
    my $workstation = $self->{workstation};
    my $plantime    = $self->{plantime};
    my $command     = $self->{command};

    my $key = $jobstream . ':' . $name;

    #
    # FROM CACHE
    #
    if ( my $entry = $JOBCACHE{$key} ) {
        my $id = $entry->{id};

        if ( $entry->{command} ne $command or $entry->{plantime} ne $plantime ) {
            my $old_command  = $entry->{command};
            my $old_plantime = $entry->{plantime};

            $logger->warn("Job $name, jobstream $jobstream has an updated command or plantime");
            $logger->warn("old command: $old_command");
            $logger->warn("new command: $command");
            $logger->warn("old plantime: $old_plantime");
            $logger->warn("new plantime: $plantime");

            $entry->{command}  = $command;
            $entry->{plantime} = $plantime;

            $self->_analyze_command;

            $db_audit->update_tws_job( plantime => $plantime, command => $command, remote => $self->{remote}, instance => $self->{instance}, nowait => $self->{nowait}, project => $self->{project}, scriptname => $self->{scriptname}, timestamp => time(), id => $id );
        }

        $self->{tws_job_id} = $id;

        return $id;
    }

    #
    # FROM DATABASE
    #
    if ( my $result = $db_audit->retrieve_tws_job( name => $name, jobstream => $jobstream ) ) {
        my $id           = $result->[0];
        my $old_plantime = $result->[5];
        my $old_command  = $result->[6];

        if ( $old_command ne $command or $old_plantime ne $plantime ) {
            $logger->warn("Job $name, jobstream $jobstream has an updated command or plantime");
            $logger->warn("old command: $old_command");
            $logger->warn("new command: $command");
            $logger->warn("old plantime: $old_plantime");
            $logger->warn("new plantime: $plantime");

            $self->_analyze_command;

            $db_audit->update_tws_job( plantime => $plantime, command => $command, remote => $self->{remote}, instance => $self->{instance}, nowait => $self->{nowait}, project => $self->{project}, scriptname => $self->{scriptname}, timestamp => time(), id => $id );
        } 

        $JOBCACHE{$key} = { id => $id, command => $command, plantime => $plantime };

        $self->{tws_job_id} = $id;

        return $id;
    }

    #
    # NOT IN CACHE OR DATABASE
    #
    $self->_analyze_command;

    my $id = $db_audit->record_tws_job( name => $name, jobstream => $jobstream, username => $username, workstation => $workstation, plantime => $plantime, command => $command, remote => $self->{remote}, instance => $self->{instance}, nowait => $self->{nowait}, project => $self->{project}, scriptname => $self->{scriptname}, timestamp => time() );

    $JOBCACHE{$key} = { id => $id, command => $command };

    $self->{tws_job_id} = $id;

    return $id;
}

#--------------------#
sub _analyze_command {
#--------------------#
    my ( $self ) = @_;


    my $command = $self->{command};

    my $inner_command;
    if ( $command =~ /^remote.pl\s+(-i\s+\d+)?\s*-c\s+"(.+)"\s*(-nowait)?\s*$/ ) {
        $self->{remote} = 'Y';

        my $instance   = $1;
        $inner_command = $2;
        my $nowait     = $3;

        if ( $instance ) {
            ( $self->{instance} ) = $instance =~ /^-i\s+(\d+)$/;
        }

        $self->{nowait} = ( $nowait ) ? 'Y' : 'N';
    }
    else {
        $self->{remote} = 'N';
        $inner_command = $command;
    }

    if ( $inner_command =~ /\-project\s+(\w+)/ ) {
        $self->{project} = $1;
    }

    my ( $script ) = $inner_command =~ /^(\S+)/;

    $self->{scriptname} = basename( $script );
}

#-----------------#
sub parse_logfile {
#-----------------#
    my ( $class, %args ) = @_;


    my %result;

    my $logger = $args{logger} or croak 'no logger defined.';

    my $logfile;
    unless ( $logfile = $result{logfile} = $args{logfile} ) {
        $logger->logdie("missing argument (logfile)");
    }

    my $fh;
    unless ( $fh = IO::File->new( $logfile, '<' ) ) {
        $logger->error("cannot open $logfile: $!");
        return;
    }

    <$fh>; # skip first line

    my $line = <$fh>; my $jobstream; my $name;
    if ( $line =~ /^= JOB\s+: (\w+)#(\w+)\[\((\d\d)(\d\d) (\d\d)\/(\d\d)\/(\d\d)\),.+\]\.([\w-]+)$/ ) {
        $result{workstation} = $1;
        $jobstream = $result{jobstream} = $2;
        $result{plantime} = $3 . ':' . $4;
        $result{plan_date} = '20' . $7 . $5 . $6 ;
        $name = $result{name} = $8;
    }
    else {
        $logger->error("logfile $logfile cannot be parsed");
        $logger->error("[1] faulty line: $line");
        $fh->close();
        return;
    }

    $line = <$fh>; my $username;
    if ( $line =~ /^= USER\s+: (\w+)/ ) {
        $result{username} = $username = $1;
    }
    else {
        $logger->error("logfile $logfile cannot be parsed");
        $logger->error("[2] faulty line: $line");
        $fh->close();
        return;
    }

    if ( $username ne $ENV{MXUSER} ) {
        $logger->info("job $name, jobstream $jobstream runs as user $username, skipping");
        $fh->close();
        return;
    }
    
    $line = <$fh>; my $command;
    if ( $line =~ /^= JCLFILE\s+: (.+)$/ ) {
        $command = $result{command} = $1;
    }
    else {
        $logger->error("logfile $logfile cannot be parsed");
        $logger->error("[3] faulty line: $line");
        $fh->close();
        return;
    }

    $line = <$fh>;
    if ( $line =~ /^= Job Number: (.+)$/ ) {
        $result{job_nr} = $1;
    }
    else {
        $logger->error("logfile $logfile cannot be parsed");
        $logger->error("[4] faulty line: $line");
        $fh->close();
        return;
    }

    $line = <$fh>;
    if ( $line =~ /^= \w{3} (\d\d)\/(\d\d)\/.?.?(\d\d) (\d\d):(\d\d):(\d\d) ([A|P]M )?[M|C]ES?T/ ) {
        my $hour = $4;
        $hour += 12 if ( $7 eq 'PM' && $hour < 12 );
        $hour = 0 if ( $hour == 12 && $7 eq 'AM ' );
        $result{starttime} = timelocal( $6, $5, $hour, $2, $1 - 1, $3 );
    }
    else {
        $logger->error("logfile $logfile cannot be parsed");
        $logger->error("[5] faulty line: $line");
        $fh->close();
        return;
    }

    while ( $line = <$fh> ) {
        last if $line =~ /^\s*Executing command : /;
    }

    if ( ! $line or $line !~ /^\s*Executing command : / ) {
        $result{logfile_pos}  = tell( $fh );
        $result{logfile_size} = -s $logfile;
        $result{stdout_begun} = -1;
    
        return \%result;
    }

    $result{stdout_begun} = 1;

    <$fh>;
    <$fh>;
    <$fh>;

    my $stdout = '';
    while ( $line = <$fh> ) {
        last if $line =~ /^=+$/; 
        $stdout .= $line;
    }
    $result{stdout} = $stdout;

    if ( $line = <$fh> ) {
        if ( $line =~ /^= Exit Status\s+: (\d+)$/ ) {
            $result{exitcode} = $1;
        } 
        else {
            $logger->error("logfile $logfile cannot be parsed");
            $logger->error("[6] faulty line: $line");
            $fh->close();
            return;
        }

        <$fh>;
        <$fh>;

        $line = <$fh>;
        if ( $line && $line =~ /^= \w{3} (\d\d)\/(\d\d)\/.?.?(\d\d) (\d\d):(\d\d):(\d\d) ([A|P]M )?[M|C]ES?T/ ) {
            my $hour = $4;
            $hour += 12 if ( $7 eq 'PM' && $hour < 12 );
            $hour = 0 if ( $hour == 12 && $7 eq 'AM ' );
            $result{endtime} = timelocal( $6, $5, $hour, $2, $1 - 1, $3 );
        }
        else {
            $logger->error("logfile $logfile cannot be parsed");
            $logger->error("[7] faulty line: $line");
            $fh->close();
            return;
        }
    }
    else {
        $result{logfile_pos}  = tell( $fh );
        $result{logfile_size} = -s $logfile;
    }

    $fh->close();

    return \%result;
}

#-------------------#
sub reparse_logfile {
#-------------------#
    my ( $self ) = @_;


    my $logger      = $self->{logger};
    my $logfile     = $self->{logfile};
    my $logfile_pos = $self->{logfile_pos};

    my $fh;
    unless ( $fh = IO::File->new( $logfile, '<' ) ) {
        $logger->error("cannot open $logfile: $!");
        $self->{endtime} = -1;
        return;
    }

    seek( $fh, $logfile_pos, SEEK_SET );

   
    unless ( $self->{stdout_begun} == 1 ) {
        my $line;
        while ( $line = <$fh> ) {
            last if $line =~ /^\s*Executing command : /;
        }

        if ( ! $line or $line !~ /^\s*Executing command : / ) {
            $self->{logfile_pos}  = tell( $fh );
            $self->{logfile_size} = -s $logfile;

            $fh->close();
            return;
        }
        else {
            $self->{stdout_begun} = 1;
    
            <$fh>;
            <$fh>;
            <$fh>;
        }
    }
  
    while ( my $line = <$fh> ) {
        last if $line =~ /^=+$/; 
        $self->{stdout} .= $line;
    }

    if ( my $line = <$fh> ) {
        if ( $line =~ /^= Exit Status\s+: (\d+)$/ ) {
            $self->{exitcode} = $1;
        } 
        else {
            $logger->error("logfile $logfile cannot be parsed");
            $logger->error("[8] faulty line: $line");
            $fh->close();
            $self->{endtime} = -1;
            return;
        }

        <$fh>;
        <$fh>;

        $line = <$fh>;
        if ( $line && $line =~ /^= \w{3} (\d\d)\/(\d\d)\/.?.?(\d\d) (\d\d):(\d\d):(\d\d) ([A|P]M )?[M|C]ES?T/ ) {
            my $hour = $4;
            $hour += 12 if ( $7 eq 'PM' && $hour < 12 );
            $hour = 0 if ( $hour == 12 && $7 eq 'AM ' );
            $self->{endtime} = timelocal( $6, $5, $hour, $2, $1 - 1, $3 );
        }
        else {
            $logger->error("logfile $logfile cannot be parsed");
            $logger->error("[9] faulty line: $line");
            $fh->close();
            $self->{endtime} = -1;
            return;
        }

        $fh->close();
        return 1;
    }
    else {
        $self->{logfile_pos}  = tell( $fh );
        $self->{logfile_size} = -s $logfile;

        $fh->close();
        return;
    }
}

#-------------#
sub scan_jobs {
#-------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    unless ( opendir DIR, '.' ) {
        $logger->logdie("cannot open '.': $!");
    }

    my @logfiles;
    while ( my $logfile = readdir( DIR ) ) {
        next if -x $logfile;

        if ( -o _ ) {
            push @logfiles, $logfile;

            $logger->info("new job found: $logfile");

            unless ( chmod( 0744, $logfile ) ) {
                $logger->logdie("cannot change file permissions of $logfile: $!");
            }
        }
    }

    closedir( DIR );

    return @logfiles;
}

#-----------#
sub endtime {
#-----------#
    my ( $self ) = @_;


    return $self->{endtime};
}

1;
