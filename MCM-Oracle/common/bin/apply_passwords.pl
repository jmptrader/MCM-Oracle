#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::XMLConfig;
use Mx::Account;
use Mx::Oracle;
use Mx::SQLLibrary;
use Mx::MxUser;
use Getopt::Long;


#---------#
sub usage {
#---------#
    print <<EOT

Usage: apply_passwords.pl [ -check ] [ -db ] [ -config ] [ -confirm ] [ -clear ]

 -check       Only report the differences, do not make changes.
 -db          Update the database with the passwords from the configfile.
 -config      Update the configfile with the passwords from the database.
 -confirm     Manually confirm each replacement.
 -clear       Show the passwords in cleartext.
 -help        Display this text.

EOT
;
    exit;
}

my ($do_check, $do_db, $do_config, $do_confirm, $clear);

GetOptions(
    'check'      => \$do_check,
    'db'         => \$do_db,
    'config'     => \$do_config,
    'confirm'    => \$do_confirm,
    'clear'      => \$clear,
);

unless ( $do_check or $do_db or $do_config ) {
    usage();
}

my $config    = Mx::Config->new();
my $logger    = Mx::Log->new( directory => $config->LOGDIR, keyword => 'apply_passwords' );
my $xmlconfig = Mx::XMLConfig->new( $config->LOCAL_DIR . '/' . $config->MXUSER . '/code/config/MurexEnv_' . $ENV{MXENV} . '.xml' );

my $configfile;
foreach my $includefile ( $xmlconfig->includes ) {
    if ( $includefile =~ /Accounts/ ) {
        $configfile = $includefile;
        last; 
    }
}

$xmlconfig = Mx::XMLConfig->new( $configfile );

my $account = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );

my $oracle = Mx::Oracle->new( username => $account->name, password => $account->password, database => $config->DB_FIN, config => $config, logger => $logger );

$oracle->open;

my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

my %users;
foreach my $key ( $xmlconfig->get_keys ) {
    if ( $key =~ /^Accounts\.(\w+)\.Password$/ ) {
        my $name = $1;

        $users{$name}->{config_password} = $xmlconfig->retrieve( $key );
        $users{$name}->{key} = $key;

        if ( my $user = Mx::MxUser->retrieve( name => $name, library => $sql_library, oracle => $oracle, config => $config, logger => $logger ) ) {
            $users{$name}->{db_password} = $user->password;
            $users{$name}->{user}        = $user;
        }
    }
}

$oracle->close;

my $dump_configfile = 0;
my $rc = 0;

print "\n"; 
foreach my $name ( keys %users ) {
    unless ( $users{$name}->{user} ) {
        print "$name: not found in the database\n";
        next;
    }

    my $cfg_password = $users{$name}->{config_password};
    my $db_password  = $users{$name}->{db_password};
    my $user         = $users{$name}->{user};
    my $key          = $users{$name}->{key};

    my $equal = $cfg_password eq $db_password;

    printf "$name: %s\n", ( $equal ? 'EQUAL' : 'NOT EQUAL' );

    printf "cfg password: %s\n", ( $clear ? Mx::MxUser->decrypt( $cfg_password ) : $cfg_password );
    printf "db  password: %s\n", ( $clear ? Mx::MxUser->decrypt( $db_password )  : $db_password );
    print "\n";

    if ( ! $equal ) {
        if ( $do_confirm && ( $do_db || $do_config ) ) {
            my $answer;
            while ( ! $answer ) {
                printf "\nUpdate %s? [y/N] ", ( $do_db ? 'database' : 'config file' );
                $answer = <STDIN>;
                chomp($answer);

                if ( $answer =~ /^y[es]?$/i ) {
                    $answer = 'yes';
                    print "\n\n";
                }
                elsif ( ! $answer or $answer =~ /^n[o]?$/i ) {
                    $answer = 'no';
                    print "\n\n";
                }
                else {
                    $answer = '';
                }
            }

            next if $answer eq 'no';
        }

        if ( $do_db ) {
            if ( $user->update_password( password => $cfg_password ) ) {
                print "database password updated\n";
            }
            else {
                $rc = 1;
                print "database password could not be updated. Please consult logfile.\n";
            }
        }
        elsif ( $do_config ) {
            $xmlconfig->set_key( $key, $db_password );
            $dump_configfile = 1;
        }
    }
}

if ( $dump_configfile ) {
    if ( $xmlconfig->dump() ) {
        print "config file $configfile updated\n";
    }
    else {
        $rc = 1;
        print "config file $configfile could not be updated. Please consult logfile\n";
    }
}

exit $rc;
