#!/usr/bin/env perl


my $pid = shift @ARGV;

   my $psinfo;

    open PSINFO, "/proc/$pid/status" or return;

    read( PSINFO, $psinfo, 128 );

    close( PSINFO );

my ($pr_flags, $pr_nlwp, $pr_pid, $pr_ppid, $pr_pgid, $pr_sid,
	 $pr_aslwpid, $pr_agentid, $pr_sigpend, $pr_brkbase, $pr_brksize, 
	 $pr_stkbase, $pr_stksize, $pr_utime, $pr_stime, $pr_cutime,
	 $pr_cstime, $filler) =
	 unpack("iiiiiiiia16iiiia8a8a8a8a",$psinfo);

print $pr_brksize, "\n";
