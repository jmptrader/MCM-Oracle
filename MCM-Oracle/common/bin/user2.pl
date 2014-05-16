#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Env;
use Mx::Config;
use Mx::Log;
use Mx::User2;
use Mx::Account;
use Mx::Sybase;
use Mx::Environment;
use Mx::Group;
use Getopt::Long;

#---------#
sub usage {
#---------#
    print <<EOT

Usage: user.pl [ -user <username> ]

 -user   <username>  Show the attributes of this user.
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

my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->MONDB_NAME, 
                  username => $account->name, password => $account->password, config => $config, logger => $logger );
$sybase->open();

my $user = Mx::User2->new( name => $name, logger => $logger, sybase => $sybase );

if ( Mx::User2->retrieve( user => $user, logger => $logger, sybase => $sybase ) ) {
    print "-----------------------------------\n";
    printf "Details for user %s\n", uc($name);
    printf "Full name   : %s\n", $user->full_name;
    print "-----------------------------------\n\n";

    if ( Mx::Environment->retrieve( user => $user, logger => $logger, sybase => $sybase ) ) {
        my @array = $user->environments;
        print "User has properties for following environments:\n";
        print "-----------------------------------------------\n\n";
        foreach my $row ( @array ) {
            printf "Id          : %s\n",$row->[0]->id;
            printf "Label       : %s\n",$row->[0]->label;
            printf "Pillar      : %s\n",$row->[0]->pillar;
            printf "Samba read  : %s\n",$row->[0]->samba_read;
            printf "Samba write : %s\n",$row->[0]->samba_write;
            my @servers = $row->[0]->servers;
            printf "Servers     : %s\n", join("\n              ", @servers);
            printf "Max sessions: %s\n",$row->[1];
            printf "Override    : %s\n",( $row->[2] ) ? 'Yes' : 'No';
            printf "Web access  : %s\n",( $row->[3] ) ? 'Yes' : 'No';
            print "-----------------------------------\n\n";
        }
    }
    else {
        print "User $name doesn't have properties for any environments\n";
        print "-------------------------------------------------------\n";
    }

    if ( Mx::Group->retrieve( user => $user, logger => $logger, sybase => $sybase ) ) {
        my @array = $user->groups;
        print "User resides in following groups:\n";
        print "---------------------------------\n\n";
        foreach my $row ( @array ) {
            printf "Id          : %s\n",$row->[0]->id;
            printf "Name        : %s\n",$row->[0]->name;
            printf "Type        : %s\n",$row->[0]->type;
            printf "Label       : %s\n",$row->[0]->label;
            print "-----------------------------------\n\n";
        }    
    }
    else {
        print "User $name doesn't belong to any groups\n";
        print "-----------------------------------------------\n";
    }
}
else {
    print "User $name cannot be retrieved \n";
}

$sybase->close();
