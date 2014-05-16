#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Collector;
use Mx::Account;
use Mx::Oracle;
use Mx::DBaudit;
use Mx::Alert;
use Time::Local;
use RRDTool::OO;
use String::CRC::Cksum qw( cksum );
use POSIX;

my $name = 'db_statement';

my $config = Mx::Config->new();
my $logger = Mx::Log->new( filename => $ARGV[0] );

my $collector = Mx::Collector->new( name => $name, config => $config, logger => $logger );

my $descriptor    = $collector->descriptor;
my $rrdfile       = $collector->rrdfile;
my $pidfile       = $collector->pidfile;
my $poll_interval = $collector->poll_interval;

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

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

my $rrd = RRDTool::OO->new( file => $rrdfile, raise_error => 0 );

my @dbs = (
  { type => 'DB_FIN', database => $config->DB_FIN, user => $config->FIN_DBUSER },
  { type => 'DB_REP', database => $config->DB_REP, user => $config->REP_DBUSER },
  { type => 'DB_MON', database => $config->DB_MON, user => $config->MON_DBUSER },
);

my $threshold_cpu            = $config->DB_THRESHOLD_CPU;
my $threshold_physical_reads = $config->DB_THRESHOLD_PHYSICAL_READS;
my $threshold_logical_reads  = $config->DB_THRESHOLD_LOGICAL_READS;

my $showplandir = $config->SHOWPLANDIR;

my %all_sessions = (); my %showplan_dumped = (); my %plan_tag = ();

foreach my $db ( @dbs ) {
    my $type = $db->{type};

    if ( $type eq 'DB_MON' ) {
        $db->{oracle} = $db_audit->oracle;
        next;
    }

    my $account = Mx::Account->new( name => $db->{user}, config => $config, logger => $logger );

    $db->{oracle} = Mx::Oracle->new( database => $db->{database}, username => $account->name, password => $account->password, logger => $logger, config => $config );

    $db->{oracle}->open();

    $all_sessions{$type} = {};
}

while ( 1 ) {
    my %logintimes = ();

    foreach my $db ( @dbs ) {
        my $type   = $db->{type};
        my $oracle = $db->{oracle};

        my $sessions = $all_sessions{$type};

        my %not_seen = ();
        map { $not_seen{ $_ } = 1 } keys %{$sessions};

        foreach my $connection ( $oracle->connections ) {
            my ( $schema, $sid, $serial, $username, $osuser, $hostname, $pid, $program, $logintime, $status, $seconds_active, $command, $cpu, $lreads, $preads, $pwrites, $blocking_sid, $wait_time, $seconds_in_wait ) = @{$connection};

            $seconds_in_wait = ( $wait_time == 0 ) ? $seconds_in_wait : 0;

            my $session_key = $sid . ':' . $serial;

            my $session;
            if ( $session = $sessions->{$session_key} ) {
                $session->{cpu_delta}     = $cpu - $session->{cpu};
                $session->{cpu}           = $cpu;
                $session->{lreads_delta}  = $lreads - $session->{lreads};
                $session->{lreads}        = $lreads;
                $session->{preads_delta}  = $preads - $session->{preads};
                $session->{preads}        = $preads;
                $session->{pwrites_delta} = $pwrites - $session->{pwrites};
                $session->{pwrites}       = $pwrites;

                delete $not_seen{ $session_key };

                if ( $status eq 'ACTIVE' && $seconds_active > $session->{seconds_active} ) {
                    $session->{seconds_active} = $seconds_active;
                    $session->{total_cpu}     += $session->{cpu_delta};
                    $session->{total_lreads}  += $session->{lreads_delta};
                    $session->{total_preads}  += $session->{preads_delta};
                    $session->{total_pwrites} += $session->{pwrites_delta};

                    $db_audit->update_statement(
                      id              => $session->{statement_id},
                      duration        => $seconds_active, 
                      cpu             => $session->{total_cpu},
                      logical_reads   => $session->{total_lreads},
                      physical_reads  => $session->{total_preads},
                      physical_writes => $session->{pwrites_delta},
                    );

                    next; 
                }
                else {
                    if ( $session->{statement_id} ) {
                        my $endtime = time() - $seconds_active;

                        $db_audit->record_statement_end( id => $session->{statement_id}, endtime => $endtime, duration => $session->{seconds_active}, plan_tag => $plan_tag{$session->{statement_id}} );

                        $session->{statement_id} = undef;
                    }

                    if ( $status eq 'ACTIVE' ) {
                        $session->{seconds_active} = $seconds_active;
                        $session->{total_cpu}      = $session->{cpu_delta};
                        $session->{total_lreads}   = $session->{lreads_delta};
                        $session->{total_preads}   = $session->{preads_delta};
                        $session->{total_pwrites}  = $session->{pwrites_delta};
                    }
                    else {
                        $session->{seconds_active} = 0;
                        $session->{total_cpu}      = 0;
                        $session->{total_lreads}   = 0;
                        $session->{total_preads}   = 0;
                        $session->{total_pwrites}  = 0;
                    }

                    next unless ( $status eq 'ACTIVE' && $seconds_active >= $poll_interval );
                }
            }
            else {
                $session = $sessions->{$session_key} = {
                  seconds_active => $seconds_active,
                  statement_id   => undef,
                  cpu            => $cpu,
                  lreads         => $lreads,
                  preads         => $preads,
                  pwrites        => $pwrites,
                  total_cpu      => 0,
                  total_lreads   => 0,
                  total_preads   => 0,
                  total_pwrites  => 0,
                };

                next unless( $status eq 'ACTIVE' && $seconds_active >= $poll_interval );
            }

            my ( $sql_text, $bind_values ) = $oracle->sql_text( sid => $sid, serial => $serial );

            unless ( $sql_text ) { # skip this statement if we cannot retrieve the SQL text
                next;
            }

            my $sql_tag = Mx::Oracle->sql_tag( $sql_text );

            my $session_id; my $script_id; my $service_id;
            if ( $pid ) {
                $session_id = $db_audit->retrieve_live_session_via_pid( pid => $pid, hostname => $hostname );

                unless ( $session_id ) {
                    $script_id = $db_audit->retrieve_live_script_via_pid( pid => $pid, hostname => $hostname );
                }

                unless ( $session_id or $script_id ) {
                    $service_id = $db_audit->retrieve_live_service_via_pid( pid => $pid, hostname => $hostname );
                }
            }

            my $starttime = time() - $seconds_active;

            my $statement_id = $db_audit->record_statement_start(
              session_id      => $session_id,
              script_id       => $script_id,
              service_id      => $service_id,
              schema          => $schema,
              sid             => $sid,
              username        => $username,
              hostname        => $hostname,
              pid             => $pid,
              osuser          => $osuser,
              program         => $program,
              command         => $command,
              starttime       => $starttime,
              duration        => $session->{seconds_active},
              cpu             => $session->{total_cpu},
              logical_reads   => $session->{total_lreads},
              physical_reads  => $session->{total_preads},
              physical_writes => $session->{total_pwrites},
              sql_text        => $sql_text,
              bind_values     => $bind_values,
              sql_tag         => $sql_tag
            );

            $session->{statement_id} = $statement_id;

            if ( ! $showplan_dumped{$statement_id} and ( $session->{total_cpu} > $threshold_cpu or $session->{total_preads} > $threshold_physical_reads or $session->{total_lreads} > $threshold_logical_reads ) ) {
                if ( my ( $rc, $plan_tag ) = dump_showplan( $oracle, $statement_id, $sid, $serial, $showplandir ) ) {
                    $showplan_dumped{$statement_id} = 1;
                    $plan_tag{$statement_id}        = $plan_tag;
                }
            }
        }

        my $endtime = time();
        foreach my $session_key ( keys %not_seen ) {
            my $session = $sessions->{$session_key};

            if ( my $statement_id = $session->{statement_id} ) {
                $db_audit->record_statement_end( id => $statement_id, endtime => $endtime, duration => $session->{seconds_active}, plan_tag => $plan_tag{$statement_id} );

                delete $showplan_dumped{$statement_id};
            }

            delete $sessions->{$session_key};
        }

        $logintimes{$type . '_login'} = $oracle->logintime();
    }

    unless ( $rrd->update( time => time(), values => \%logintimes ) ) {
        $logger->error("cannot update $rrdfile: " . $rrd->error_message);
    }

    sleep $poll_interval;
}

$process->remove_pidfile();


#-----------------#
sub dump_showplan {
#-----------------#
    my ( $oracle, $statement_id, $sid, $serial, $showplandir ) = @_;


    my $dumpfile = $showplandir . '/' . $statement_id . '.sp';
    my $rc = 1;

    unless ( -f $dumpfile ) {
        $logger->info("dumping showplan of statement $statement_id");

        my @lines = $oracle->sql_plan( sid => $sid, serial => $serial );

        return unless @lines > 1;

        my $fh;
        unless ( $fh = IO::File->new( $dumpfile, '>' ) ) {
            $logger->error("cannot open $dumpfile: $!");
            return;
        }

        my $total_plan_string = '';
        while ( my $line = shift @lines ) {
            print $fh "$line\n";

            $total_plan_string .= $line;
        }

        $fh->close;

        my $plan_tag = cksum( $total_plan_string );

        return ( $rc, $plan_tag );
    }

    return $rc;
}

