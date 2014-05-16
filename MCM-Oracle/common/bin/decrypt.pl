#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Env;
use Mx::Account;
use Mx::Config;

my $config = Mx::Config->new();
my $password = $ARGV[0];

printf "%s\n", Mx::Account->decrypt($password, $config->KEY);
