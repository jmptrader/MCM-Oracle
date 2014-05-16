#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::User;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: user.pl [ -user <username> ]

 -user <username>  Show the attributes of this user.
 -help             Display this text.

EOT
;
    exit;
}

#
# process the commandline arguments
#
my ($name, $details);

GetOptions(
    'user=s'        => \$name,
    'help'          => \&usage,
);

#
# read the configuration files
#
my $config  = Mx::Config->new();

#
# initialize logging
#
my $logger  = Mx::Log->new( directory => $config->LOGDIR, keyword => 'user' );

if ( my $user = Mx::User->retrieve( name => $name, config => $config, logger => $logger ) ) {
    printf "Details for user %s:\n\n", $name;
    printf "Maximum number of sessions: %d\n", $user->max_sessions;
    printf "Default printer: %s\n", $user->printer;
    printf "Can login to a disabled server: %s\n", ( $user->override ) ? 'yes' : 'no';
    printf "Full name: %s\n", $user->full_name;
    printf "Web Access: %s\n", ( $user->web_access ) ? 'yes' : 'no';
    printf "Environments:\n %s\n", join "\n ", $user->env; 
}
else {
    printf "user $name cannot be retrieved\n";
}
