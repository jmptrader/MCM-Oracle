#!/usr/bin/env perl

use strict;
use warnings;

use Mx::Config;
use Mx::Log;


my @PROJECTS = qw( );

my $config = Mx::Config->new();

foreach my $project ( @PROJECTS ) {
    $config->set_project_variables( $project );

    Mx::Log->create_logdir( directory => $config->PROJECT_LOGDIR );
}
