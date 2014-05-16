#!/usr/bin/env perl

use strict;
use warnings;

use Mx::MxUser;

my $password = $ARGV[0];

printf "%s\n", Mx::MxUser->encrypt( $password );
