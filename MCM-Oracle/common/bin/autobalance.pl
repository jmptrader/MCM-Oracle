#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::Audit;
use Mx::Context;
use Mx::Account;
use Mx::Sybase;
use Mx::SQLLibrary;
use Mx::Batch;
use Mx::Book;
use Mx::Report;
use Mx::Util;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes;

my @BATCH_NAMES    = (); # List of all the batch names that can be used.
my @RUNNING        = (); # This is a list of all currently running batches. The size of this list cannot be greater than the allowed concurrency. 
my @READY          = (); # List of batches which are ready to be used.
my @FAILED         = (); # List of batches that have failed and should be rescheduled.
my %LATEST_RUNTIME = (); # List of the most recent starttime for each batch name.
my $SYNCHRONIZED   = 0;  # Semaphore to avoid race conditions while manipulating previous lists.
my $NR_BOOKS_OK    = 0;
my $NR_BOOKS_NOK   = 0;



#---------#
sub usage {
#---------#
    print <<EOT

Usage: autobalance.pl [ -batch <batchname> ] [ -books file1,file2,... ] [ -books all ] [ -excludes file1,file2,... ] [ -parallel <number> ] [ -sleep <seconds> ] [ -max_booksize <seconds> ] [ -max_nr_books <number> ] [ -max_percentage <number> ] [ -max_runtime <seconds> ] [ -timings <id> ] [ -outputdir <directory> ] [ -header <size> ] [ -footer <size> ] [ -debug ] [ -sched_jobid <id> ] [ -sched_runid <id> ] [ -help ]

or

Usage: autobalance.pl [ -rerun <autobalance id> ] [ -batch <batchname> ] [ -parallel <number> ] [ -sleep <seconds> ] [ -max_booksize <seconds> ] [ -max_nr_books <number> ] [ -max_percentage <number> ] [ -max_runtime <seconds> ] [ -timings <id> ] [ -outputdir <directory> ] [ -header <size> ] [ -footer <size> ] [ -debug ] [ -sched_jobid <id> ] [ -sched_runid <id> ] [ -help ]


 -batch <batchname>       Name of the batch to execute.
 -books file1,file2,..    List of files containing lists of books to process.
 -books all               All books defined in Murex.
 -excludes file1,file2    List of files containing lists of books to exclude.
 -parallel <number>       Maximum number of concurrent batches.
 -sleep <seconds>         Wait interval before 're-using' a batch.
 -max_booksize <seconds>  Maximum runtime a book may have before it can be included in a multibook.
 -max_nr_books <number>   Maximum number of single books a multibook may contain.
 -max_percentage <number> Maximum runtime of a multibook as a percentage of the runtime of the largest single book (0 to disable this setting).
 -max_runtime <seconds>   Maximum absolute size of a multibook (0 to disable this setting). 
 -timings <session_id>    Use the timings of AB session 'session_id' instead of the most recent.
 -outputdir <directory>   Directory where the reports must be written.
 -header <size>           Number of lines in the report header.
 -footer <size>           Number of lines in the report footer.
 -debug                   Enable performance statistics
 -sched_jobid <id>        Job ID in the UC4 scheduler (optional).
 -sched_runid <id>        Run ID in the UC4 scheduler (optional).
 -rerun <id>              Restart a failed autobalance run, while recuperating the finished sub-reports
 -help                    Display this text.

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
my ($batch, $books, $excludes, $parallel, $sleep, $max_booksize, $max_nr_books, $max_percentage, $max_runtime, $timings_session_id, $outputdir, $header, $footer, $debug, $sched_jobid, $sched_runid, $rerun );

GetOptions(
    'batch=s'          => \$batch,
    'books=s'          => \$books,
    'excludes=s'       => \$excludes,
    'parallel=i'       => \$parallel,
    'sleep=i'          => \$sleep,
    'max_booksize=i'   => \$max_booksize,
    'max_nr_books=i'   => \$max_nr_books,
    'max_percentage=i' => \$max_percentage,
    'max_runtime=i'    => \$max_runtime,
    'timings=i'        => \$timings_session_id,
    'outputdir=s'      => \$outputdir,
    'header=i'         => \$header,
    'footer=i'         => \$footer,
    'debug!'           => \$debug,
    'sched_jobid=s'    => \$sched_jobid,
    'sched_runid=s'    => \$sched_runid,
    'rerun=i'          => \$rerun,
    'help'            => \&usage,
);

#
# read the configuration files
#
my $config = Mx::Config->new();

#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'autobalance' );

#
# initialize auditing
#
my $audit = Mx::Audit->new( directory => $config->AUDITDIR, keyword => 'autobalance', logger => $logger );

$audit->start($args);

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );

#
# initialize the Sybase connection
#
my $sybase = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, config => $config, logger => $logger );

#
# open the Sybase connection
#
$sybase->open();

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );

#
# setup the runtime parameters
#
my $MAX_CONCURRENCY          = $parallel       || $config->retrieve("AB_MAX_CONCURRENCY");
my $SLEEP_INTERVAL           = $sleep          || $config->retrieve("AB_SLEEP_INTERVAL");
my $MULTIBOOK_MAX_BOOKSIZE   = $max_booksize   || $config->retrieve("AB_MULTIBOOK_MAX_BOOKSIZE");
my $MULTIBOOK_MAX_NR_BOOKS   = $max_nr_books   || $config->retrieve("AB_MULTIBOOK_MAX_NR_BOOKS");
my $MULTIBOOK_MAX_PERCENTAGE = $max_percentage || $config->retrieve("AB_MULTIBOOK_MAX_PERCENTAGE");
my $MULTIBOOK_MAX_RUNTIME    = $max_runtime    || $config->retrieve("AB_MULTIBOOK_MAX_RUNTIME");
my $HEADER_SIZE              = $header         || $config->retrieve("AB_HEADER_SIZE");
my $FOOTER_SIZE              = $footer         || $config->retrieve("AB_FOOTER_SIZE");
my $OUTPUTDIR                = $outputdir      || $config->retrieve("AB_OUTPUTDIR");
my $CONFIGDIR                = $config->retrieve("AB_CONFIGDIR");
my $MIN_CHECK_TIME           = $config->retrieve("AB_MIN_CHECK_TIME");
my $MIN_CPU_SECONDS          = $config->retrieve("AB_MIN_CPU_SECONDS");
my $NR_RETRIES               = $config->retrieve("AB_NR_RETRIES");
my $CHECK_INTERVAL           = $config->retrieve("AB_CHECK_INTERVAL");

#
# create the proper account
#
my $context_obj;
unless ( $context_obj = Mx::Context->new( name => 'bo', config => $config, logger => $logger ) ) {
    $audit->end("context 'bo' cannot be found", 1);
}
my $mx_account;
unless ( $mx_account = $context_obj->account() ) {
    my $user = $context_obj->user();
    $audit->end("account $user cannot be found", 1);
}

my $hostname = Mx::Util->hostname();
my $db_audit = Mx::DBaudit->new( logger => $logger, config => $config );

my $template = $config->XMLDIR . '/batch.xml';

#
# retrieve the defined autobalance batch templates from Murex
#
unless ( @BATCH_NAMES = Mx::Batch->get_autobalance_names( name => $batch, library => $sql_library, sybase => $sybase, logger => $logger ) ) {
    $audit->end("cannot find a batch called $batch", 1);
}
$logger->debug("available batches: @BATCH_NAMES"); 

#
# determine the batch type: MXRISK or REGULAR
#
my $batch_type = Mx::Batch->check_batch_type( name => $BATCH_NAMES[0], sybase => $sybase, library => $sql_library, logger => $logger );

#
# Initialize the hash containing the most recent starttimes
#
foreach ( @BATCH_NAMES ) {
    $LATEST_RUNTIME{$_} = 0;
}

my $ab_session_id; my @packages = (); my @finished_reports = ();
if ( $rerun ) {
    $ab_session_id = $rerun;
    $db_audit->update_ab_session( id => $ab_session_id, pid => $$ );
    $NR_BOOKS_OK = $db_audit->retrieve_nr_books_ok( id => $ab_session_id );
    my @book_ids = $db_audit->retrieve_unfinished_ab_books( id => $ab_session_id );
    my %books = (); my $max_nr_runs = 0;
    foreach my $book_id ( @book_ids ) {
        $logger->debug("restoring book #$book_id");
        my $book = Mx::Book->restore_book( id => $book_id, timings => $timings_session_id, sybase => $sybase, library => $sql_library, config => $config, logger => $logger );
        my $reference = $book->reference;
        my $nr_runs   = $book->nr_runs;
        $max_nr_runs = $nr_runs if $nr_runs > $max_nr_runs;
        $books{$reference} = [] unless exists $books{$reference};
        push @{ $books{$reference} }, $book;
    }
    $NR_RETRIES += $max_nr_runs;
    foreach my $key ( keys %books ) {
        my $report_id = $db_audit->record_report_start( ab_session_id => $ab_session_id, type => 'file' );
        push @packages, [ $key, $books{$key}, $report_id ];
    }
    my @report_ids = $db_audit->retrieve_finished_ab_reports( id => $ab_session_id );
    foreach my $report_id ( @report_ids ) {
        $logger->debug("restoring report #$report_id");
        my $report = Mx::Report->restore_report( id => $report_id , config => $config, logger => $logger );
        push @finished_reports, $report;
    }
}
else {
    unless ( $books ) {
        $audit->end("no bookfiles specified", 1);
    }
    #
    # record the session in the database
    #
    $ab_session_id = $db_audit->record_ab_session_start( batchname => $batch, cmdline => $args, hostname => $hostname, sched_jobid => $sched_jobid, sched_runid => $sched_runid, pid => $$ );

    my @bookfiles = split /,/, $books;
    map { $_ =~ s/^\s*(\S.*\S)\s*$/$1/ } @bookfiles;
    $logger->debug("book files: @bookfiles");

    my @excludefiles = ();
    if ( $excludes ) {
        @excludefiles = split /,/, $excludes;
        map { $_ =~ s/^\s*(\S.*\S)\s*$/$1/ } @excludefiles;
    }
    $logger->debug("exclude files: @excludefiles");

    @packages = read_bookfiles( $batch, \@bookfiles, \@excludefiles, $sybase, $sql_library );
}

#
# for each package, consolidate all the books in the package
#
foreach my $package ( @packages ) {
    my $reference = $package->[0];
    $logger->info("consolidating package $reference");
    my @books     = @{$package->[1]};
    my $nr_books  = @books;
    $logger->info("consolidating package $reference, currently $nr_books books");
    @books        = consolidate_books(@books);
    $nr_books     = @books;
    $logger->info("after consolidation, $nr_books books");
    $package->[1]   = [ @books ];
}

#
# setup the signal handler
#
$SIG{ALRM} = \&check;

#
# activate the periodic check
#
alarm($CHECK_INTERVAL);

#
# Main loop. We don't stop until all books are processed and all batches finished successfully or failed.
#
my @books = (); my @packages_copy = @packages;
LOOP: while ( @RUNNING || @FAILED || @books || @packages ) {
    #
    # acquire the semaphore
    #
    sem_get_wait();
    #
    # Before we start with a new book, first check if there are batches that failed. If so, add their books to the beginning of the booklist
    # to give them a VIP treatment.
    #
    if ( my $fbatch = shift @FAILED ) {
        sem_put();
        my $fbook = $fbatch->book();
        my $fbook_name = $fbook->name();
        if ( $fbook->nr_runs() > $NR_RETRIES ) {
            $fbook->abort();
            $logger->error("book $fbook_name had $NR_RETRIES retries, and is still failing. Skipping this one.");
            $NR_BOOKS_NOK += $fbook->nr_books();
        }
        else {
            $fbook->reset();
            unshift @books, $fbook->split();
            $logger->error("book $fbook_name failed, split and scheduled for re-run.");
        }
        next LOOP;
    }
    #
    # If there is a book, start a new batch for this book
    #
    if ( @books ) {
        #
        # If the book does not have the right status, skip it
        #
        if ( ! $books[0]->ready() ) {
            sem_put();
            my $bookname = $books[0]->name();
            shift @books;
            $logger->warn("skipping book $bookname for run as is does not have status 'ready'"); 
            next LOOP;
        }
        #
        # Check if there is a batch name available
        #
        my $batch_name;
        unless ( $batch_name = shift @READY ) {
            sem_put();
            $logger->debug("no free batch available, going to sleep again");
            sleep $CHECK_INTERVAL;
            next LOOP;
        }
        $logger->debug("batch $batch_name is available");
        my $nbook      = shift @books;
        my $nbook_name = $nbook->name();
        my $runtime    = $nbook->runtime();
        $logger->debug("processing book $nbook_name, estimated runtime $runtime seconds");
        my $outputfile = undef; my $outputtable = undef;
        if ( $batch_type == Mx::Batch->MXRISK ) {
            my $nbook_name_no_blanks = $nbook_name;
            $nbook_name_no_blanks =~ s/\s//g;
            $outputtable = uc( substr( $batch . '_' . $nbook_name_no_blanks, 0, 20) );
            $logger->debug("outputtable will be called $outputtable");
        }
        else {
            my $nbook_name_underscored = $nbook_name;
            $nbook_name_underscored =~ tr(/ )(__);
            $outputfile = $OUTPUTDIR . '/' . $batch . '_' . $nbook_name_underscored . '.txt'; 
            $logger->debug("outputfile will be called $outputfile");
        }
        my $nbatch;
        unless ( $nbatch = Mx::Batch->new( name => $batch_name, ab_session_id => $ab_session_id, outputfile => $outputfile, outputtable => $outputtable, template => $template, account => $mx_account, sybase => $sybase, library => $sql_library, config => $config, logger => $logger ) ) {
            $audit->end("cannot instantiate new batch $batch_name", 1);
        }
        unless ( $nbatch->define_books( book => $nbook, sybase => $sybase, library => $sql_library ) ) {
            $audit->end("cannot redefine batch $batch_name", 1);
        }
        unless ( $nbatch->run( background => 1, debug => $debug ) ) {
            $audit->end("cannot run batch $batch_name", 1);
        }
        $nbook->start( session_id => $nbatch->id() );
        $LATEST_RUNTIME{$batch_name} = time();
        push @RUNNING, $nbatch;
        sem_put();
        next LOOP;
    }
    #
    # Our list of books is empty, let's see if there are any remaining packages.
    #
    if ( @packages ) {
        sem_put();
        my $package   = shift @packages;
        my $reference = $package->[0];
        @books        = @{$package->[1]};
        my $booklist  = join ',', map { $_->name() } @books;
        my $nr_books  = @books;
#        $logger->info("starting package $reference, containing following books: $booklist");
        $logger->info("starting package $reference, containing $nr_books books");
        next LOOP;
    }
    sem_put();
    #
    # If we got here, it means there are no more books to do, we only have to wait for the running processes to finish, so let's sleep a while...
    #
    $logger->debug("waiting for remaining batches to finish...");
    sleep $CHECK_INTERVAL;
}

@packages = @packages_copy;

#
# building the global reports
#
if ( $batch_type == Mx::Batch->REGULAR ) {
    foreach my $package ( @packages ) {
        my $reference = $package->[0];
        $logger->debug("starting consolidation of all reports for package $reference");
        my @books     = @{$package->[1]};
        my $report_id = $package->[2]; 
        my $report_path = $OUTPUTDIR . '/' . $batch . '_' . $reference . '.txt';
        $logger->debug("resulting report will be called $report_path");
        my $fh;
        unless ( $fh = IO::File->new( $report_path, '>' ) ) {
            $audit->end("cannot open $report_path: $!", 1);
        }
        my @good_books = ();
        foreach my $book ( @books ) {
            push @good_books, $book if $book->status eq 'FINISHED';
        }
        my $count = 1; my $total = @good_books;
        my @reports = @finished_reports;
        push @reports, ( map { $_->report } @good_books ); 
        foreach my $report ( @reports ) {
            my $skip_header; my $skip_footer;
            #
            # skip the header for all reports but the first, and skip the footer for all reports but the last
            #
            $skip_header = ( $count == 1 )      ? 0 : $HEADER_SIZE;
            $skip_footer = ( $count == $total ) ? 0 : $FOOTER_SIZE;
            print $fh $report->text( skip_header => $skip_header, skip_footer => $skip_footer );
            $count++;
        }
        $fh->close();
        my $report = Mx::Report->new( id => $report_id, file => $report_path, config => $config, logger => $logger );
        $report->archive();
        $db_audit->record_report_end( report_id => $report_id, txt_path => $report->txt_path, txt_size => $report->txt_size, nr_lines => $report->nr_lines );
    }
}

$db_audit->record_ab_session_end( session_id => $ab_session_id, nr_books_ok => $NR_BOOKS_OK, nr_books_nok => $NR_BOOKS_NOK );
$db_audit->close();

$sybase->close();

print $ab_session_id, "\n";

$audit->end($args, 0);

#
# Defines lists of books to work upon, using the same order as the bookfiles specified on the commandline.
# Books on the excludelist are filtered out, as are duplicate books within the same bookfile.
# Duplicate books in different bookfiles are instantiated only once so the reports can be reused.
#
#------------------#
sub read_bookfiles {
#------------------#
    my ( $batch, $bookfiles, $excludefiles, $sybase, $library ) = @_;

    my @results = ();
    #
    # build the list of books to be excluded
    #
    my @excludes = ();
    foreach my $file ( @{$excludefiles} ) {
        #
        # if the path is not an absolute one, prepend the configdir
        #
        if ( substr($file, 0, 1) ne '/' ) {
            $file = "$CONFIGDIR/$file";
        }
        my $fh;
        unless ( $fh = IO::File->new( $file, '<' ) ) {
            $audit->end("cannot open $file: $!", 1);
        }
        while ( my $book = <$fh> ) {
            next if $book =~ /^#/;
            chomp($book);
            #
            # remove leading and traling spaces
            #
            $book =~ s/^\s*(\S.*\S)\s*$/$1/;
            push @excludes, Mx::Book->explode( book => $book, sybase => $sybase, library => $library, logger => $logger );
        }
        $fh->close();
    }
    my %global_occurence = ();
    foreach my $file ( @{$bookfiles} ) {
        my @books = (); my @book_objects = (); my %local_occurence = (); my $reference;
        if ( $file eq 'all') {
            $reference = 'all';
            @books = Mx::Book->all_books( sybase => $sybase, library => $library, logger => $logger );
        }
        else {
            #
            # if the path is not an absolute one, prepend the configdir
            #
            if ( substr($file, 0, 1) ne '/' ) {
                $file = "$CONFIGDIR/$file";
            }
            $reference = fileparse( $file, qr/\.[^.]*/ );
            my $fh;
            unless ( $fh = IO::File->new( $file, '<' ) ) {
                $audit->end("cannot open $file: $!", 1);
            }
            while ( my $book = <$fh> ) {
                next if $book =~ /^#/;
                chomp($book);
                #
                # remove leading and traling spaces
                #
                $book =~ s/^\s*(\S.*\S)\s*$/$1/;
                push @books, Mx::Book->explode( book => $book, sybase => $sybase, library => $library, logger => $logger );
            }
            $fh->close();
        }
        $logger->debug("current reference is $reference");
        foreach my $book ( @books ) {
            #
            # if the book is already in the current list, skip it
            #
            if ( $local_occurence{$book} ) {
                $logger->warn("multiple occurences of $book within the same file, skipping one");
                next;
            }
            #
            # same thing when is appears in the exclude list
            #
            if ( grep /^$book$/, @excludes ) {
                $logger->warn("$book is in the excludelist, skipping");
                next;
            }
            #
            # remember that you've seen the book
            #
            $local_occurence{$book} = 1;
            my $book_object;
            #
            # if the book has EVER been used before, re-use the object
            #
            if ( $book_object = $global_occurence{$book} ) {
                #
                # as the report of this book will have to be re-used, it should not become part of a multibook
                #
                $book_object->disable_multibook();
                $logger->warn("multiple occurences of $book within the same run, re-using previous result, disabling multibook capacity");
            }
            else {
                if ( $book_object = Mx::Book->new( name => $book, batch => $batch, ab_session_id => $ab_session_id, reference => $reference, timings => $timings_session_id => config => $config, logger => $logger, sybase => $sybase, library => $library ) ) {
                    $logger->debug("adding $book to the list");
                    $global_occurence{$book} = $book_object;
                }
                else {
                    $logger->error("cannot work with $book, skipping...");
                    next;
                }
            }
            push @book_objects, $book_object;
        }
        my $report_id = $db_audit->record_report_start( ab_session_id => $ab_session_id, type => 'file' );
        push @results, [ $reference, \@book_objects, $report_id ];
    }
    return @results;
}

#
# Consolidate small single books in so-called 'multibooks', to avoid the overhead of each time having to
# start a new session.
#
#---------------------#
sub consolidate_books {
#---------------------#
    my ( @books ) = @_;

    #
    # First sort the books, smallest first
    #
    @books = sort { $a->runtime() <=> $b->runtime() } @books;
    #@books = sort { $a->name() cmp $b->name() } @books;
    my @result = ();
    while ( my $book = shift @books ) {
        #
        # keep on adding books until you're not allowed anymore
        #
        while ( my ($next_book) = @books ) {
            last unless $book->add_book( book => $next_book, max_booksize => $MULTIBOOK_MAX_BOOKSIZE, max_nr_books => $MULTIBOOK_MAX_NR_BOOKS, max_percentage => $MULTIBOOK_MAX_PERCENTAGE, max_runtime => $MULTIBOOK_MAX_RUNTIME );
            shift @books;
        }
        push @result, $book;
        my $name    = $book->name();
        my $mxbooks = join ',', $book->book_list();
        $logger->debug("book $name contains following Murex books: $mxbooks");
        $book->db_insert() unless $book->bookid_list();
    }
    #
    # sort the result so that the books with the largest runtime come first
    #
    @result = sort { $b->runtime() <=> $a->runtime() } @result;
    return @result;
}

#---------#
sub check {
#---------#
   #
   # try to claim the semaphore or wait until the next time
   #
   unless ( sem_get() ) {
       alarm($CHECK_INTERVAL);
       return;
   }
   #
   # check if no process on the runlist is finished or is hanging
   #
   my @running = ();
   while ( my $batch = shift @RUNNING ) {
       my $batch_name = $batch->name();
       #$logger->debug("checking on running batch $batch_name");
       #
       # give the batch some time to start
       #
       if ( $batch->runtime() < $SLEEP_INTERVAL ) {
#           $logger->debug("skipping, too young");
           push @running, $batch;
           next;
       }
       if ( $batch->is_still_running() ) {
           #$logger->debug("$batch_name is still running");
           if ( $batch->is_checked() || $batch->runtime() < $MIN_CHECK_TIME ) {
               push @running, $batch;
#               $logger->debug("check not necessary");
               next;
           }
           my $process = $batch->mx_process() || $batch->req_process();
           $process->update_performance();
           my $cpu_seconds = $process->cputime();
           if ( $cpu_seconds > $MIN_CPU_SECONDS ) {
               #
               # once the batch is ok, it doesn't need to be re-checked
               #
               $batch->is_checked(1);
               push @running, $batch;
               $logger->debug("$batch_name has consumed $cpu_seconds cpu seconds, everything ok");
           }
           else {
               $logger->error("$batch_name has only consumed $cpu_seconds cpu seconds, and will be killed");
               $batch->kill();
               $batch->book->fail();
               push @FAILED, $batch;
           }
       }
       else {
           if ( $batch->status() == Mx::Batch->FAILED ) {
               $batch->book->fail();
               push @FAILED, $batch;
               $logger->error("$batch_name is not running anymore, and has apparently failed");
           }
           else {
               my $book = $batch->book();
               my $bookname = $book->name();
               my $report;
               if ( $batch_type == Mx::Batch->REGULAR and my %outputfiles = $batch->outputfiles() ) {
                   my ( $report_id, $txt_path ) = %outputfiles;
                   $report = Mx::Report->new( id => $report_id, file => $txt_path, scriptname => $batch_name, config => $config, logger => $logger );
               }
               elsif ( $batch_type == Mx::Batch->MXRISK and my %outputtables = $batch->outputtables() ) {
                   my ( $id1, $id2 ) = keys %outputtables;
                   my $report_id = ( $id1 < $id2 ) ? $id1 : $id2;
                   $report = Mx::TableReport->new( id => $report_id, tablename => $outputtables{$report_id}, tableowner => $config->retrieve('TABLEOWNER'), sybase => $sybase, config => $config, logger => $logger );
               }
               if ( $report ) {
                   $book->report( $report );
                   $book->finish();
                   my $runtime      = $book->runtime();
                   my $real_runtime = $book->real_runtime();
                   $logger->info("$batch_name (book: $bookname estimated runtime: $runtime s actual runtime: $real_runtime s) has successfully finished");
                   $NR_BOOKS_OK += $book->nr_books();
               }
               else {
                   $batch->book->fail();
                   push @FAILED, $batch;
                   $logger->error("batch $batch_name has no produced a report");
               }
           }
       }
   }
   @RUNNING = @running;
   my $nr_running = @RUNNING;
   #$logger->debug("$nr_running batch(es) running");
   #
   # we will only add one batch per run to the ready list (if possible) as this piece of code will run often enough
   #
   if ( @RUNNING + @READY < $MAX_CONCURRENCY ) {
       #
       # and we will add the oldest batch first
       #
       my $oldest = time() - $SLEEP_INTERVAL; my $batch_name = undef;
       while ( my ($name, $start_time) = each %LATEST_RUNTIME ) {
           #
           # if the same batch is already present on the readylist, skip it
           #
           next if grep /^$name$/, @READY;
           if ( $start_time < $oldest ) {
               $oldest     = $start_time;
               $batch_name = $name;
           }
       }
       push @READY, $batch_name if $batch_name;
   }
   sem_put();
   #
   # re-set the alarm
   #
   alarm($CHECK_INTERVAL);
}

#-----------#
sub sem_get {
#-----------#
    if ( $SYNCHRONIZED ) {
        return 0;
    }
    else {
        return $SYNCHRONIZED = 1;
    }
}

#----------------#
sub sem_get_wait {
#----------------#
   while ( $SYNCHRONIZED ) {
       usleep(10000);
   }
   return $SYNCHRONIZED = 1;
}

#-----------#
sub sem_put {
#-----------#
    $SYNCHRONIZED = 0;
}

