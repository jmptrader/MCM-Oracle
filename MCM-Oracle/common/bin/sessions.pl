#!/usr/bin/env perl

use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Process;
use Mx::Secondary;
use Mx::DBaudit;
use Mx::Auth::User;
use Mx::Auth::DB;
use Getopt::Long;
use Storable qw( freeze thaw );

#---------#
sub usage {
#---------#
    print <<EOT

Usage: sessions.pl [ -user <username> ] [ -list ] [ -kill ] [ -perf ] [ -rebuild ] [-kill_location <location>]

 -list                Show details of the sessions.
 -user <username>     Show only the sessions of this user.
 -perf                Include performance data.
 -kill                Kill all sessions or the sessions of a specific user.
 -rebuild             Rebuild the session count map.
 -kill_location	<loc> Kill all user sessions with the specified location
 -help                Display this text.

EOT
;
    exit;
}

# Store the arguments
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($user, $list, $perf, $kill, $rebuild, $killlocation);

GetOptions(
    'list!'         => \$list,
    'user=s'        => \$user,
    'perf!'         => \$perf,
    'kill!'         => \$kill,
    'rebuild'       => \$rebuild,
    'kill_location=s'    => \$killlocation,
    'help'          => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'sessions' );

Mx::Secondary->init( logger => $logger, config => $config );

$logger->info("sessions.pl $args");
my $hostname = Mx::Util->hostname;
$logger->info("Hostname = $hostname") ;

#
# connect to the secondary monitors
#
my @handles = Mx::Secondary->handles( config => $config, logger => $logger );

map { $_->sessions_async } @handles;

my @all_sessions; my %handles;
foreach my $handle ( @handles ) {
    $handles{ $handle->short_hostname } = $handle;

    push @all_sessions, $handle->poll_async;
}

my @user_sessions = ();
if ( $user ) {
    foreach my $session ( @all_sessions ) {
        push @user_sessions, $session if $session->win_user eq $user;
    }
}

my @sessions = ( $user ) ? @user_sessions : @all_sessions;

if ( $list ) {

    printf "\nTotal number of sessions: %d\n", scalar( @all_sessions ); ;
    printf "Number of sessions for user $user: %d\n", scalar( @user_sessions ) if $user;

    printf "\n";

    if ( $perf ) {
        printf "%5s %8s %20s %10s %30s %15s %30s %5s %5s %10s %10s\n", 'PID', 'HOST', 'USER', 'CLIENT', 'NICK', 'MX_PID', 'START DATE', 'PCPU', 'PMEM', 'VSZ', 'RSS';
        printf "%5s %8s %20s %10s %30s %15s %30s %5s %5s %10s %10s\n", '---', '----', '----', '------', '----', '------', '----------', '----', '----', '---', '---';
    } 
    else {
        printf "%5s %8s %20s %10s %30s %15s\n", 'PID', 'HOST', 'USER', 'CLIENT', 'NICK', 'MX_PID';
        printf "%5s %8s %20s %10s %30s %15s\n", '---', '----', '----', '------', '----', '------';
    }

    foreach my $session ( @sessions ) {
        printf "%5d %8s %20s %10s %30s %15d", $session->pid, $session->hostname, $session->win_user, $session->mx_client_host, $session->mx_nick, $session->mx_pid;
        if ( $perf ) {
            printf " %30s %5s %5s %10s %10s",  scalar(localtime($session->starttime)), $session->pcpu, $session->pmem, $session->vsz, $session->rss;
        }
        print "\n";
    }

    print "\n";
    
	
}

if ( $killlocation ) {
		$logger->info("Killing sessions in $killlocation");
    my $auth_db = Mx::Auth::DB->new( config => $config, logger => $logger );
    my $session_counter = 0;
    my $session_kill_counter = 0;
    foreach my $session ( @sessions ) {
    		my $win_user = $session->win_user;
    		if($win_user && $win_user ne 'murex1' && $win_user ne 'murexcd'){
        my $user_auth = Mx::Auth::User->new( name => $win_user,db => $auth_db, config => $config, logger => $logger );
   			$user_auth->retrieve;
	   			if($killlocation eq $user_auth->location){
	   				$session_counter = $session_counter+1;
							my $pid      = $session->pid;
			        my $hostname = $session->hostname;
			
			        print "killing session with pid $pid on $hostname...";
			        $logger->info("killing session with pid $pid on $hostname...");
			
			        my $rv;
			        if ( my $handle = $handles{$hostname} ) {
			            $rv = $handle->soaphandle->kill_session( $pid )->result;
			        }
			
			        if ( $rv ) {
			        	$session_kill_counter = $session_kill_counter +1;
			            print "killed\n";
			            $logger->info("killed");
			        }
			        else {
			            print "failed\n";
			            $logger->info("failed");
			        }
	   			}
   			}
    }
    if($session_counter > 0){$logger->info("$session_counter were found for killing, $session_kill_counter were actually killed");}
    else{$logger->info("No sessions found for killing in $killlocation");}
    
}

if ( $kill ) {
    foreach my $session ( @sessions ) {
        my $pid      = $session->pid;
        my $hostname = $session->hostname;

        print "killing session with pid $pid on $hostname...";
        $logger->info("killing session with pid $pid on $hostname...");

        my $rv;
        if ( my $handle = $handles{$hostname} ) {
            $rv = $handle->soaphandle->kill_session( $pid )->result;
        }

        if ( $rv ) {
            print "killed\n";
            $logger->info("killed");
        }
        else {
            print "failed\n";
            $logger->info("failed");
        }
    }
}


if ( $rebuild ) {
    $logger->info("rebuilding session count table");

    my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

    my %user_sessions = (); my %sessions = ();

    foreach my $session ( @all_sessions ) {
	my $mx_scripttype = $session->mx_scripttype;
	my $win_user      = $session->win_user;
	my $hostname      = $session->hostname;
        if ( $win_user ) {
            $user_sessions{$win_user}->{$hostname}++;
        }
        else {
            $sessions{$mx_scripttype}->{$hostname}++; 
        }
    }

    my @sessions = ();

    foreach my $win_user ( keys %user_sessions ) {
        foreach my $hostname ( keys %{$user_sessions{$win_user}} ) {
            my $count = $user_sessions{$win_user}->{$hostname};
            push @sessions, { win_user => $win_user, mx_scripttype => 'user session', hostname => $hostname, count => $count };
        }
    }

    foreach my $mx_scripttype ( keys %sessions ) {
        foreach my $hostname ( keys %{$sessions{$mx_scripttype}} ) {
            my $count = $sessions{$mx_scripttype}->{$hostname};
            push @sessions, { mx_scripttype => $mx_scripttype, hostname => $hostname, count => $count };
        }
    }

    $db_audit->rebuild_session_counts( sessions => \@sessions, config => $config, logger => $logger );
 
    $db_audit->close();
}
