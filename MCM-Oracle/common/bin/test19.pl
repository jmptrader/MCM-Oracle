#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Ant;

my $config = Mx::Config->new();
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mxml_tasks' );

my $template = $config->XMLDIR . '/list_tasks.xml';

my $script;
unless ( $script = Mx::Ant->new( name => 'list_tasks', template => $template, target => 'listtasks', config => $config, logger => $logger, no_extra_logdir => 1, no_audit => 1 ) ) {
    $logger->logdie("ant session could not be initialized");
}

$script->run( exclusive => 1, no_output => 1 );

my $output = $script->output;

my $i = 0;
foreach my $line ( split /\n/, $output ) {
    print $line . "\n";
    if ( $line =~ / - Task: (\w+) - (.+)$/ ) {
        $i++;
        printf "%4d %-50s: %s\n", $i, $1, $2;
    }
}
