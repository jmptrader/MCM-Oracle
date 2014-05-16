#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Logfile;
use Mx::Ant;
use File::stat;
use Fcntl qw( :seek );
use POSIX;

my $XSLT_PROGRAM = '/usr/bin/xsltproc';

my $name = 'session';
 
my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );
 
my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );
 
my $descriptor     = $collector->descriptor;
my $pidfile        = $collector->pidfile;
my $poll_interval  = $collector->poll_interval;
my $audit_interval = 15; 
 
#
# become a daemon
#
my $pid = fork();
exit if $pid;
unless ( defined($pid) ) {
    $logger->logdie("cannot fork: $!");
}

unless ( setsid() ) {
    $logger->logdie("cannot start a new session: $!");
}

#
# create a pidfile
#
my $process = Mx::Process->new( descriptor => $descriptor, logger => $logger, config => $config, light => 1 );
unless ( $process->set_pidfile( $0, $pidfile ) ) {
    $logger->logdie("not running exclusively");
}

my $template      = $config->XMLDIR . '/list_sessions.xml';
my $sessions_xslt = $config->XMLDIR . '/list_sessions.xsl';
my $services_xslt = $config->XMLDIR . '/list_services.xsl';
my $sessions_xml  = $config->RUNDIR . '/sessions.xml';
my $sessions_lst  = $config->SESSION_MAP;
my $services_lst  = $config->SERVICE_MAP;
my $auditfile     = $config->MXENV_ROOT . '/logs/audit/groups.txt';

while ( ! -e $auditfile ) {
    $logger->debug("$auditfile does not exist yet, going to sleep");
    sleep 60;
}

unless ( open( FH, "< $auditfile" ) ) {
    $logger->logdie("cannot open $auditfile: $!");
}
seek( FH, 0, SEEK_END );
my $curr_pos = tell(FH);
close(FH);

my $curr_size = stat( $auditfile )->size;

my $nr_iterations  = $poll_interval / $audit_interval;
my $curr_iteration = $nr_iterations - 1;

while ( 1 ) {
    $curr_iteration++;

    if ( $curr_iteration == $nr_iterations ) {
        my $script;
        unless ( $script = Mx::Ant->new( name => 'list_sessions', template => $template, target => 'listservers', config => $config, logger => $logger, no_extra_logdir => 1, no_audit => 1 ) ) {
           $logger->logdie("ant session could not be initialized");
        }

        $script->run( exclusive => 1 );
 
        unless ( $script->exitcode == 0 ) {
            $logger->error("ant session failed");
            $curr_iteration = $nr_iterations - 1;
            sleep $poll_interval;
            next;
        }

        unless ( -f $sessions_xml ) {
            $logger->error("xml output not found");
            $curr_iteration = $nr_iterations - 1;
            sleep $poll_interval;
            next;
        }

        system("$XSLT_PROGRAM -o $sessions_lst $sessions_xslt $sessions_xml");
        system("$XSLT_PROGRAM -o $services_lst $services_xslt $sessions_xml");

        $curr_iteration = 0;
    }

    while ( ! -e $auditfile ) {
        $logger->debug("$auditfile does not exist yet, going to sleep");
        sleep 60;
    }
    
    my $size = stat( $auditfile )->size;

    if ( $size != $curr_size ) {
        unless( open( FH_IN, "< $auditfile" ) ) { 
            $logger->logdie("cannot open $auditfile: $!");
        }

        unless ( open( FH_OUT, ">> $sessions_lst" ) ) {
            $logger->logdie("cannot open $sessions_lst: $!");
        }

        seek( FH_IN, $curr_pos, SEEK_SET );

        while ( my $line = <FH_IN> ) {
            if ( $line =~ /^[\w-]+;(\w+);([\w-]+);.+;NPID:(\d+)$/ ) {
                print FH_OUT "$3:_:$1:$2\n";
            }
        }

        $curr_pos  = tell(FH_IN);
        $curr_size = $size;

        close(FH_IN);
        close(FH_OUT);
    }

    sleep $audit_interval;
}

$process->remove_pidfile();
