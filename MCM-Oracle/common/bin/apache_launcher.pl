#!/usr/bin/env perl


use POSIX 'setsid';

if ( my $pid = fork() ) {
    print "$pid\n";
    exit 0;
}

open STDIN,  '/dev/null';

if ( $logfile = $ENV{APACHE_LOGFILE} ) {
    open STDOUT, ">>$logfile";
}
else {
    open STDOUT, '>>/dev/null';
}

open STDERR, '>&STDOUT';

setsid();

if ( $dir = $ENV{APACHE_CHDIR} ) {
    chdir($dir);
}

if ( $pidfile = $ENV{APACHE_PIDFILE} ) {
    if ( open FH, ">$pidfile" ) {
        print FH "$$\n";
        close(FH);
    }
}

exec(@ARGV);
