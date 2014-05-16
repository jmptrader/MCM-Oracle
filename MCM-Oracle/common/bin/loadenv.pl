#!/usr/bin/env perl

# ##########################################################
# loadenv.pl loads a database dump or application directoy #
# ##########################################################
# Date      User    Change                                 #
# --------  ------  -------------------------------------- #
# 20101013  U30293  Load xxx type database                 #       
# ##########################################################

use warnings;
use strict;

use Carp;

use File::Find;
use File::Basename;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::DBaudit;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Service;
use Mx::Murex;
use Mx::Util;
use Mx::Process;
use Getopt::Long;
use Switch;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: loadenv.pl [ -load ] [-db <dbtype>] [ -appl ] [ -templates ] [ -passwords ] [ -clean ] [ -force ] [ -extreme ] [ -dumpdir <dumpdirectory> ] [ -dumpfile <dumpfile> ] [ -applfile <applfile> ]

 -load                          Load the Sybase database
 -dbtype                        In case of load, specify the db type (mx,mlc,rep) to load
 -stripes                       Override default number of stripes
 -appl                          Load the application directory.
 -templates                     Only re-install the configuration files.
 -passwords                     Only re-set all Murex passwords.
 -clean                         Empty the log and data directories.
 -dumpdir <dumpdirectory>       Override the default dump directory.
 -dumpfile <dumpfile>           Override the default dump file.
 -applfile <applfile>           Override the default application file.
 -force                         Continue even when there are still open database connections.
 -extreme                       Do not try to stop Murex first.
 -start                         Start the murex services afterwards.
 -help                          Display this text.

EOT
;
    exit;
}

#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($do_load, $dbtype, $do_appl, $do_templates, $do_passwords, $do_clean, $dumpdir, $dumpfile, $applfile, $force, $extreme, $do_start, $stripes);

GetOptions(
    'load!'      => \$do_load,
    'dbtype=s'   => \$dbtype,
    'stripes=s'  => \$stripes,
    'appl!'      => \$do_appl,
    'templates!' => \$do_templates,
    'passwords!' => \$do_passwords,
    'clean!'     => \$do_clean,
    'dumpdir=s'  => \$dumpdir,
    'dumpfile=s' => \$dumpfile,
    'applfile=s' => \$applfile,
    'force!'     => \$force,
    'extreme!'   => \$extreme,
    'start!'     => \$do_start,
    'help'       => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'loadenv' );

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'loadenv', logger => $logger );

$audit->start($args);

#
# setup the Sybase accounts
#
my $account    = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 
my $sa_account = Mx::Account->new( name => $config->MX_SAUSER, config => $config, logger => $logger ); 
my $ts_account = Mx::Account->new( name => $config->MX_TSUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connection (without specifying the database name)
#
my $sybase    = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );
my $sa_sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $sa_account->name, password => $sa_account->password, error_handler => 1, config => $config, logger => $logger );
my $ts_sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $ts_account->name, password => $ts_account->password, error_handler => 1, config => $config, logger => $logger );

# open the Sybase connection
$sybase->open();
$sa_sybase->open();
$ts_sybase->open();

my $my_spid    = $sybase->spid;
my $my_sa_spid = $sa_sybase->spid;
my $my_ts_spid = $ts_sybase->spid;

# setup the SQL library
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

# determine the name of the database
my $db_name;

switch ($dbtype) {
		case "mx"	 { $db_name = $config->DB_NAME; }
		case "mlc" { $db_name = $config->DB_MLC;  }
		case "rep" { $db_name = $config->DB_REP;  }
		else       { croak "Unknown dbtype. Type must be mx,mlc or rep."; }
}		

$logger->info("name of the database is $db_name");

#
# determine the dumpdirectory, if empty take DUMPDIR from the config
#
$dumpdir = $dumpdir || $config->DUMPDIR;

if ( ( $do_load || $do_appl ) && ! $extreme ) {
	  # stop Murex and kill sybase connections
    stop_murex( $db_name, $config );
}

if ( $do_load ) {
    #
    # determine the number of database stripes, based on the application type
    #
    my $nr_stripes = $stripes || $config->DUMPSTRIPES;
    $logger->info("Number of expected database stripes is $nr_stripes");
    #
    # determine the name of the dumpfile
    unless ( $dumpfile ) {
    	  # determine the most recent dump name and stripe the last character (normally the stripe number)
    	  my $laststripe = basename(most_recent_database_stripe($dumpdir, $dbtype));
    	  chop($laststripe);
        $dumpfile = $dumpdir . "/${laststripe}";
    }
    unless ( substr( $dumpfile, 0, 1 ) eq '/' ) {
        $dumpfile = "$dumpdir/$dumpfile";
    }
    my $extension = ( $nr_stripes > 0 ) ? '1' : '';
    unless ( my $fh = IO::File->new("$dumpfile$extension", '<' ) ) {
        $audit->end("cannot open dumpfile $dumpfile", 1);
    }

    load_db( $sa_sybase, $db_name, $dumpfile, $nr_stripes, $force );
}

if ( $do_load || $do_passwords ) {
#    configure_db( $sybase, $db_name, $config );
}

if ( $do_appl ) {
    #
    # determine the application directory where the extraction must take place
    #
    my $appldir = $config->MXENV_ROOT;
    #
    # determine the name of the applfile
    #
    unless ( $applfile ) {
        $applfile = $dumpdir . "/${db_name}_appdir.tar.gz";
    }
    unless ( substr( $applfile, 0, 1 ) eq '/' ) {
        $applfile = "$dumpdir/$applfile";
    }
    unless ( my $fh = IO::File->new("$applfile", '<' ) ) {
        $audit->end("cannot open applfile $applfile", 1);
    }

    load_appl($db_name, $applfile, $appldir);
}

if ( $do_appl || $do_clean ) {
    cleanup();
}

if ( $do_appl || $do_templates ) {
    install_templates( $config );
}

if ( $do_start ) {
    start_murex( $db_name, $config );
}

$audit->end($args, 0);

#------------------------------#
sub most_recent_database_stripe {
#------------------------------#	
    my $dir = shift;
    my $type= shift;
    -d $dir or die "'$dir' is not a directory\n";
    my %files;
    if ( $type eq "mx" ) {
    	 #look for db in the name when loading mx database dump
       $type="db";
    }
    File::Find::find (
        sub {
            my $name = $File::Find::name;

            return unless $name =~ /.*_${type}_.*\.stripe/;

            # print "Found ". $name ." stripe files\n";
            $files{$name} = (stat $name)[9] if -f $name;
        }, $dir
    );

    unless ( keys %files ) {
       die "No dumpfile of type ". $type . " found in " . $dir;
    }

    ( sort { $files{$a} <=> $files{$b} } keys %files )[-1];
    
}


#-----------#
sub load_db {
#-----------#
    my ($sybase, $db_name, $dumpfile, $nr_stripes, $force) = @_; 

    $logger->info("starting a database load for $db_name, using dumpfile $dumpfile");
    my ($query, $result);
    #
    # check if a LOAD or DUMP database is already running
    #
    $query = $sql_library->query('load_or_dump_check');
    if ( $result = $sybase->query(query => $query, values => [ $db_name ]) ) {
        my @spids = map { $_->[0] } @{$result};
        if ( @spids ) {
            $audit->end("there is already a dump or load running on $db_name, please check spid(s) @spids", 1);
        }
        else {
            $logger->info("no dump or load running on $db_name");
        }
    }
    #
    # check for open connections to the database (apart from ours)
    # 
    $query = $sql_library->query('open_connections_check');
    if ( $result = $sybase->query(query => $query, values => [ $db_name, $my_spid, $my_sa_spid ]) ) {
        my @spids = map { $_->[0] } @{$result};
        if ( @spids ) {
            if ( $force ) {
                $logger->warn("there are still connections open to $db_name - spid(s) @spids - continuining as -force was specified");
            } else {
                $audit->end("there are still connections open to $db_name, please check spid(s) @spids, or use -force", 1);
            }
        }
        else {
            $logger->info("no open connections to $db_name");
        }
    }
    #
    # build the SQL statement for loading
    #
    my $load_statement = "load database $db_name\n"; 
    for (my $i = 1; $i <= $nr_stripes; $i++) {
        $load_statement .= ( $i == 1 ? 'from       ' : 'stripe on' ) . " 'compress::$dumpfile" . ( $nr_stripes > 0 ? "$i" : '' ) . "'\n";  
    }
    unless ( $sybase->do( statement => $load_statement ) ) {
        $audit->end("load of database $db_name failed", 1);
    }
    $logger->info("database load for $db_name finished");
    $logger->info("bringing database $db_name online");
    unless ( $sybase->do( statement => "online database $db_name" ) ) {
        $audit->end("onlining of $db_name failed", 1);
    }
    $logger->info("database $db_name is online");
    return 1;
}

#----------------#
sub configure_db {
#----------------#
     my ($sybase, $db_name, $config) = @_;

    $logger->info('starting database configuration');
    $sybase->use($db_name);
    $sybase->do( statement => 'sp_configure "allow updates to system tables", 1' );
    $sybase->do( statement => 'update sysobjects set loginame = NULL where loginame != NULL' );
    $sybase->do( statement => 'sp_configure "allow updates to system tables", 0' );
    my $sqluser = $config->retrieve('SQLUSER');
    foreach my $login ($sqluser, 'MXG2000') {
        $sybase->do( statement => "sp_dropalias $login" );
        $sybase->do( statement => "sp_addalias $login, 'MUREXDB'" );
    }
    my $accounts_ref;
    unless ( $accounts_ref = $config->ACCOUNTS ) {
            $logger->logdie('cannot access the accounts section in the configuration file');
    }
    my $version = $config->retrieve('VERSION'); my $production = ( uc( $config->retrieve('PROD') ) eq 'Y' );
    foreach my $name ( keys %{$accounts_ref} ) {
        my $account;
        unless ( $account = Mx::Account->new( name => $name, config => $config, logger => $logger ) ) {
            $logger->warn("cannot initialize account $name, skipping");
            next;
        }
        my $password = $account->password;
        my $statement;
        my $tag = ( $version < 3 && $name eq 'SUPERVISOR' ) ? 'mx_supervisor_password_reset' : 'mx_user_password_reset';
        unless ( $statement = $sql_library->query($tag) ) {
            $logger->logdie('query with as key $tag cannot be retrieved from the library');
        }
        $statement =~ s/__USER__/$name/g;
        $statement =~ s/__PASSWORD__/$password/g;
        $sybase->do( statement => $statement);
    }
    if ( $version < 3 && ! $production ) {
        my $statement;
        unless ( $statement = $sql_library->query('olk_reset') ) {
            $logger->logdie('query with as key olk_reset cannot be retrieved from the library');
        }
        $sybase->do( statement => $statement);
    }
    $sybase->use('master');
    $logger->info('database configuration done');
}

#-------------#
sub load_appl {
#-------------#
    my ($db_name, $applfile, $appldir) = @_;
 
    
    $logger->info("starting extraction of $applfile into $appldir");
    unless ( Mx::Util->extract( archive => $applfile, workdir => $appldir, config => $config, logger => $logger ) ) {
        $audit->end('extraction of application archive failed', 1);
    }
    $logger->info("extraction finished");
    return 1;
}

#--------------#
sub stop_murex {
#--------------#
    my ($db_name, $config) = @_;


    $logger->info('stopping all Murex services');
    my @services = Mx::Service->list(config => $config, logger => $logger);
    my $count = 0;
    foreach my $service ( reverse @services ) {
        my $name = $service->name();
        if ( $service->stop( db_audit => $db_audit ) ) {
           $count++;
           $logger->info("service $name is stopped");
        } else {
           $logger->error("unable to stop service $name");
        }
    }

    if ( $count == @services) {
        $logger->info('all Murex services stopped');
    }
    else {
        $logger->warn('not all Murex services could be stopped');
    }

    $logger->info('killing al the Murex sessions');

    foreach my $process ( Mx::Process->list( logger => $logger, config => $config ) ) {
        if ( $process->type == $Mx::Process::MXSESSION ) {
            $process->kill;
        }
    }

    $logger->info('killing al the Sybase connections');
    if ( $ts_sybase->kill_all( $db_name ) ) {
        $logger->info('all Sybase connections are killed');
    }
    else {
        $logger->warn('unable to kill all Sybase connections');
    }
}

#---------------#
sub start_murex {
#---------------#
    my ($db_name, $config) = @_;

    $logger->info('starting all Murex services');
    my @services = Mx::Service->list(config => $config, logger => $logger);
    my $count = 0;
    foreach my $service ( @services ) {
        my $name = $service->name();
        if ( $service->start( db_audit => $db_audit ) ) {
           $count++;
           $logger->info("service $name is started");
        } else {
           $logger->error("unable to start service $name");
        }
    }
    if ( $count == @services) {
        $logger->info('all Murex services started');
    }
    else {
        $logger->warn('not all Murex services could be started');
    }
}

#---------------------#
sub install_templates {
#---------------------#
    my ($config) = @_;

    $logger->info('installing the templates');
    Mx::Murex->install_templates( config => $config, logger => $logger );
    $logger->info('all templates installed');
}

#-----------#
sub cleanup {
#-----------#
    my $emptylist_ref = $config->EMPTY_OR_CREATE_DIR;
    foreach my $dir ( @{$emptylist_ref} ) {
        if ( -d $dir ) {
            Mx::Util->rmdir( directory => $dir, logger => $logger );
        }
        else {
            Mx::Util->mkdir( directory => $dir, logger => $logger );
        }
    }
}

