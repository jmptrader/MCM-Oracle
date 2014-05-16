#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Util;
use Mx::Murex;
use Mx::Process;
use Getopt::Long;
use IO::File;
use File::Copy;
use File::Basename;

my $DEFAULT_DESK    = 'MM';
my $DEFAULT_PLCC    = 'PLCC_BR';
my $DEFAULT_PC      = 'PC_BRUSSELS';
my $DEFAULT_ENTITY  = 'BR';

#---------#
sub usage {
#---------#
    print <<EOT

Usage: backupenv.pl [ -dump ] [ -dbtype <dbtype> ] [ -appl ] [ -archive ] [ -force ] [ -kill ] [ -nodates ] [ -modifier ] [ -help ]

 -dump          Dump the Sybase database.
 -dbtype        Type of database to dump: mx, mlc or rep. Default is mx.
 -appl          Dump the application directory.
 -archive       Archive the database and/or the application dump.
 -force         Continue even when there are still open database connections.
 -kill          Kill all Murex sessions and database connections first.
 -nodates       Do not try do determine the FO, BO and ACC date.
 -modifier      Optional modifier to the default output file names.
 -help          Display this text.

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
my ($do_dump, $db_type, $do_appl, $do_archive, $force, $kill, $modifier, $nodates);

GetOptions(
    'dump!'      => \$do_dump,
    'dbtype=s'   => \$db_type,
    'appl!'      => \$do_appl,
    'archive!'   => \$do_archive,
    'force!'     => \$force,
    'kill!'      => \$kill,
    'nodates'    => \$nodates,
    'modifier=s'   => \$modifier,
    'help'       => \&usage,
);
$modifier =~ s/\W+//g if( $modifier );
#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'backupenv' );

#
# initialize auditing
#
my $audit   = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'backupenv', logger => $logger );

$audit->start($args);

#
# setup the Sybase accounts
#
my $account    = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger ); 
my $sa_account = Mx::Account->new( name => $config->MX_SAUSER, config => $config, logger => $logger ); 

#
# initialize the Sybase connections (without specifying the database name)
#
my $sybase    = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );
my $sa_sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, username => $sa_account->name, password => $sa_account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connections
#
$sybase->open();
$sa_sybase->open();

my $my_spid    = $sybase->spid;
my $my_sa_spid = $sa_sybase->spid;

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

#
# determine the name of the dabase
#
$db_type = $db_type || 'mx';

my $db_name;
if ( $db_type eq 'mx' ) {
    $db_name = $config->DB_NAME;
}
elsif ( $db_type eq 'rep' ) { 
    $db_name = $config->DB_REP;
    $nodates = 1;
}
elsif ( $db_type eq 'mlc' ) { 
    $db_name = $config->DB_MLC;
    $nodates = 1;
}
else {
    $logger->logdie("wrong dbtype specified: $db_type");
}

$logger->info("name of the database is $db_name");

#
# retrieve the Murex dates
#
my ($fo_date, $mo_date, $bo_date, $acc_date) = @_;
unless ( $nodates ) {
    $sybase->use($db_name);
    $fo_date  = Mx::Murex->date(type => 'FO',  label => $DEFAULT_DESK,   sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
    $mo_date  = Mx::Murex->date(type => 'MO',  label => $DEFAULT_PLCC,   sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
    $bo_date  = Mx::Murex->date(type => 'BO',  label => $DEFAULT_PC,     sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
    $acc_date = Mx::Murex->date(type => 'ACC', label => $DEFAULT_ENTITY, sybase => $sybase, library => $sql_library, config => $config, logger => $logger);
    $sybase->use('master');
}
my $long_dump_date = localtime();
my ($sec, $min, $hour, $day, $month, $year) = ( localtime() )[ 0 .. 5 ];
my $short_dump_date = sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;
my $formatted_long_dump_date  = sprintf "%04s%02s%02s_%02s%02s%02s", $year + 1900, $month, $day, $hour, $min, $sec;

$logger->info("name of the database is $db_name");

#
# determine the dump directory and check if it exists
#
my $dumpdir = $config->DUMPDIR;
if ( -d $dumpdir ) {
    $logger->info("dump directory is $dumpdir");
} else {
    $audit->end("dump directory $dumpdir does not exist", 1);
}

if ( $kill ) {
    $logger->info('killing al the Murex sessions');
    foreach my $process ( Mx::Process->list( logger => $logger, config => $config ) ) {
        if ( $process->type == $Mx::Process::MXSESSION ) {
            $process->kill;
        }
    }
    $logger->info('killing al the Sybase connections');
    if ( $sybase->kill_all( $db_name ) ) {
        $logger->info('all Sybase connections are killed');
    }
    else {
        $logger->warn('unable to kill all Sybase connections');
    }
}

if ( $do_dump ) {
    #
    # determine the number of database stripes, based on the application type
    #
    my $nr_stripes = $config->DUMPSTRIPES;
    $logger->info("number of database stripes is $nr_stripes");

    dump_db($sa_sybase, $db_name, $dumpdir, $nr_stripes, $force);
}

if ( $do_appl ) {
    dump_appl($db_name, $dumpdir);
}

if ( $do_archive ) {
    #
    # determine the archive directory and create it
    #
    my $date = ( $nodates ) ? $short_dump_date : $fo_date;
    my $archivedir = "$dumpdir/archives/${db_name}_" . $date;
    unless (-d $archivedir) {
        if ( Mx::Util->mkdir( directory => $archivedir, logger => $logger ) ) {
            $logger->debug("created archive directory $archivedir");
        }
        else {
            $audit->end("could not create archive directory $archivedir: $!");
        }
    }
    if ( $do_dump ) {
        archive_dump($db_name, $dumpdir, $archivedir);
    } 
    if ( $do_appl ) {
        archive_appl($db_name, $dumpdir, $archivedir);
    } 
}

$sybase->close();
$sa_sybase->close();
$audit->end($args, 0);

#------------#
sub file_name{
#------------#
    my( $db_name, $ext ) = @_; 

    my $fn = $db_name.( $modifier ? "_$modifier" : '' ).( $ext ? ".$ext" : '' );
    return $fn;
}

#-----------#
sub dump_db {
#-----------#
    my ($sybase, $db_name, $dumpdir, $nr_stripes, $force) = @_; 

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
    # create an info file in the dump directory containing all dates
    #
#    my $info_file = "${dumpdir}/${db_name}.info";
    my $filename = "${db_name}_${formatted_long_dump_date}.dump";
    my $info_file = $dumpdir.'/'.file_name( $filename , 'info' );
    if ( my $fh = IO::File->new($info_file, '>') ) {
        print $fh "DUMPDATE $long_dump_date\n";
        unless ( $nodates ) {
            print $fh "  FODATE $fo_date\n";
            print $fh "  MODATE $fo_date\n";
            print $fh "  BODATE $bo_date\n";
            print $fh " ACCDATE $acc_date\n";
        }
        $fh->close;
    }
    else {
        $audit->end("cannot create info file $info_file: $!", 1);
    }
    #
    # determine the name of the backup file(s)
    #
#    my $stripe_file = "${dumpdir}/${db_name}.bck";
    my $stripe_file = $dumpdir.'/'.file_name( $filename, 'stripe' );
    #
    # build the SQL statement for dumping
    #
    my $dump_statement = "dump database $db_name\n"; 
    for (my $i = 1; $i <= $nr_stripes; $i++) {
        $dump_statement .= ( $i == 1 ? 'to       ' : 'stripe on' ) . " 'compress::$stripe_file" . ( $nr_stripes > 1 ? "$i" : '' ) . ".wait'\n";  
    }

    $sybase->checkpoint();
    unless ( $sybase->do( statement => $dump_statement ) ) {
        $audit->end("dump of database $db_name failed", 1);
    }
    #
    # rename the created stripes
    #
    for (my $i = 1; $i <= $nr_stripes; $i++) {
        my $new_name = $stripe_file . ( $nr_stripes > 1 ? "$i" : '' );
        my $old_name = $new_name . '.wait';
        if ( -s $old_name ) {
            if ( rename $old_name, $new_name ) {
                $logger->debug("renamed stripe $old_name to $new_name");
            }
            else {
                $audit->end("rename of stripe $old_name to $new_name failed: $!", 1);
            }
        }
        else {
            $audit->end("stripe $old_name is missing or is empty", 1)
        }
    }
    return 1;
}

#----------------#
sub archive_dump {
#----------------#
    my ($db_name, $dumpdir, $archivedir) = @_; 


    unless ( opendir(DUMPDIR, $dumpdir) ) {
        $audit->end("cannot access $dumpdir: $!");
    }
    my $fn = file_name( $db_name );
    while ( my $file = readdir(DUMPDIR) ) {
#        if ( $file =~ /^(${db_name}\.bck(\.\d+))|(${db_name}\.info)$/ ) {
        if( $file =~ /^($fn\.bck(\.*\d*))|($fn\.info)$/ ){
            my $source = "$dumpdir/$file";
            my $target = "$archivedir/$file";
            $logger->debug("copying $source to $target");
            unless ( copy($source, $target) ) {
                $audit->end("copy of $source to $target failed: $!", 1);
            }
            $logger->debug("copied $source to $target");
        }
    }
    closedir(DUMPDIR);
}

#-------------#
sub dump_appl {
#-------------#
    my ($db_name, $dumpdir) = @_;

    my $workdir = $config->MXENV_ROOT;
#    my $tarfile = "${dumpdir}/${db_name}_appdir.tar";
    my $tarfile = $dumpdir.'/'.file_name( $db_name ).'_appdir.tar';
    my @files   = qw(.); 
    my $excludelist_ref = $config->EXCLUDE_FILE;
    unless ( Mx::Util->tar(
        tarfile => $tarfile, workdir => $workdir, files => \@files, excludelist => $excludelist_ref, config => $config, logger => $logger)
    ) {
        $audit->end('tarring of application directory failed', 1);
    }
    unless ( Mx::Util->compress(sourcefile => $tarfile, targetfile => "${tarfile}.gz", erase => 1, config => $config, logger => $logger) ) {
        $audit->end('compressing of application directory failed', 1);
    }
    return 1;
}

#----------------#
sub archive_appl {
#----------------#
    my ($db_name, $dumpdir, $archivedir) = @_;

    #my $source = "${dumpdir}/${db_name}_appdir.tar.gz";
    my $source = $dumpdir.'/'.file_name( $db_name ).'_appdir.tar.gz';
    #my $target = "${archivedir}/${db_name}_appdir.tar.gz";
    my $target = $archivedir.'/'.file_name( $db_name ).'_appdir.tar.gz';
    $logger->debug("copying $source to $target");
    unless ( copy($source, $target) ) {
        $audit->end("copy of $source to $target failed: $!", 1);
    }
    $logger->debug("copied $source to $target");
    return 1;
}
