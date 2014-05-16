#!/usr/bin/env perl

use Fcntl qw( :seek );

my $pid = $ARGV[0];

my ( $arg_vector, $nr_args, $env_vector ) = perf( $pid );

perf2( $pid, $arg_vector, $nr_args, $env_vector );

#--------#
sub perf {
#--------#
    my ( $pid ) = @_;

    my $psinfo;

    open PSINFO, "/proc/$pid/psinfo" or return;

    read( PSINFO, $psinfo, 256 );

    close( PSINFO );

    my ( $pr_flag,
         $pr_nlwp,
         $pr_pid,
         $pr_ppid,
         $pr_pgid,
         $pr_sid,
         $pr_uid,
         $pr_euid,
         $pr_gid,
         $pr_egid,
         $pr_addr,
         $pr_size,
         $pr_rssize,
         $pr_pad1,
         $pr_ttydev,
         $pr_pctcpu,
         $pr_pctmem,
         $pr_start,
         $pr_time,
         $pr_ctime,
         $pr_fname,
         $pr_psargs,
         $pr_wstat,
         $pr_argc,
         $pr_argv,
         $pr_envp,
         $pr_dmodel,
         $pr_taskid,
         $pr_projid,
         $pr_nzomb,
         $filler ) = unpack( "iiiiiiiiiiIiiiiSSa8a8a8Z16Z80iiIIaa3iiia", $psinfo );

    my ( $secs, $nsecs ) = unpack( "LL", $pr_time );

    $pr_pctcpu = sprintf "%.1f", $pr_pctcpu / 327.68;
    $pr_pctmem = sprintf "%.1f", $pr_pctmem / 327.68;

    print "pct cpu: $pr_pctcpu\n";
    print "pct mem: $pr_pctmem\n";
    print "vsize:   $pr_size\n";
    print "rssize:  $pr_rssize\n";
    print "nlwp:    $pr_nlwp\n";
    print "cpusec:  $secs\n"; 
    print "cmdline: $pr_psargs\n\n";

    return ( $pr_argv, $pr_argc, $pr_envp );
}

#---------#
sub perf2 {
#---------#
    my ( $pid, $arg_vector, $nr_args, $env_vector ) = @_;


    my $buffer; 

    open AS, "/proc/$pid/as" or return;

    seek( AS, $arg_vector, SEEK_SET );

    read( AS, $buffer, 4 * $nr_args );

    my @addresses = unpack( 'I' x $nr_args, $buffer );

    seek( AS, $env_vector, SEEK_SET );

    read( AS, $buffer, 4 );

    my $env_address = unpack( 'I', $buffer );

    push @addresses, $env_address;

    my $address = shift @addresses;

    seek( AS, $address, SEEK_SET );

    while ( my $next_address = shift @addresses ) {
        my $length  = $next_address - $address;

        read( AS, $buffer, $length );

        print "$buffer\n";

        $address = $next_address;
    }

    close(AS);
}
