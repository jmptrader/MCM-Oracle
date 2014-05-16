#!/usr/bin/env perl

use warnings;
use strict;

use Mx::Config;
use Mx::Log;
use Mx::Mail;


my $config = Mx::Config->new();

my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mail' );

my $message = Mx::Mail->new( from => 'mario.truyens@kbc.be', to => 'mario@unicase.be', subject => 'This is a test', body => 'blabla', logger => $logger, config => $config );

$message->send();
