#!/usr/bin/env perl

package MyApp::Mason;

use strict;
use HTML::Mason::ApacheHandler;

{
    package HTML::Mason::Commands;
    
    use lib "$ENV{LCH_HOME}/$ENV{MXUSER}/projects/common/lib";
    use Apache::DBI;
    require Mx::Mason::Config;
    require Mx::Mason::HTML;
    require Mx::Env;
    require Mx::Config;
    require Mx::Log;
    require Mx::Process;
    require Mx::Service;
    require Mx::Collector;
    require Mx::MxUser;
    require Mx::Util;
    require Mx::Account;
    require Mx::Oracle;
    require Mx::Database::Index;
    require Mx::SQLLibrary;
    require Mx::DBaudit;
    require Mx::Secondary;
    require Mx::Murex;
    require Mx::System;
    require Mx::Ant;
    require Mx::Session::Argument;
    require Mx::Project;
    require Mx::MxML::Node;
    require Mx::MxML::Message;
    require Mx::SLA;
    require Mx::Alert;
    require Mx::Job;
    require Mx::Error;
    require Mx::Network::Ping;
    require Mx::Auth::User;
    require Mx::Auth::Group;
    require Mx::Auth::Environment;
    require Mx::Auth::Right;
    require Mx::Auth::DB;
    require Mx::Message;
    require Mx::Datamart::Report;
    require Mx::BCT::Report;
    require Mx::MDML;
    require Mx::Runtime;
    require Mx::Filesystem;
    require Mx::ControlM::Job;
    require Mx::ControlM::Table;
    use Apache2::Request;
    use File::Basename;
    use XML::Simple;
    use GD::Graph::area;
    use GD::Graph::bars;
    use GD::Graph::hbars;
    use GD::Graph::lines;
    use GD::Graph::colour;
    use RRDTool::OO;
    use SOAP::Lite;
    use Time::Local;
    use Date::Calc qw(:all);
    use URI::Escape;
    use XML::Parser;
    use BerkeleyDB;
    use Perl::Tidy;
    use Tie::File;
    use SQL::Tokenizer;
    use SQL::Beautify;
    use JSON::XS;
    use MIME::Base64 qw(decode_base64url);
    use IO::Uncompress::Gunzip qw( gunzip $GunzipError );
    use Data::Dumper;
    use Archive::Zip;
    use HTML::Escape qw( escape_html );

    use vars qw( $config $logger $app_name $db_audit $auth_db $account $oracle $oracle_fin $oracle_rep $oracle_mon %schemas $library @app_servers @handles %handles $system %full_names @services @collectors @projects $environments %users %client_map %mxml_nodes %mxml_tasks );
    use vars qw( %callbacks $description $search_button $go_back_button $refresh_button $list_method $details_method @columns %columns $table_name $table_width %extra_indexes %murex_indexes );

    $config        = Mx::Config->new();
    $logger        = Mx::Log->new( directory => $config->LOGDIR, keyword => 'web' );

    $account       = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
    $oracle_fin    = Mx::Oracle->new( database => $config->DB_FIN, username => $account->name, password => $account->password, config => $config, logger => $logger );
    $oracle        = $oracle_fin;

    $account       = Mx::Account->new( name => $config->REP_DBUSER, config => $config, logger => $logger );
    $oracle_rep    = Mx::Oracle->new( database => $config->DB_REP, username => $account->name, password => $account->password, config => $config, logger => $logger );

    %schemas       = (
	  $config->FIN_DBUSER => $oracle_fin,
	  $config->REP_DBUSER => $oracle_rep,
    );

    $library       = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
    $system        = Mx::System->new( config => $config, logger => $logger );
    @app_servers   = map { Mx::Util->hostname( $_ ) } $config->retrieve_as_array( 'APP_SRV' );
    @services      = Mx::Service->list( config => $config, logger => $logger );
    @projects      = Mx::Project->retrieve_all( config => $config, logger => $logger );
    @projects      = sort { $a->name cmp $b->name } @projects;
    Mx::Collector->init_disabled_collectors( config => $config );
    @collectors    = Mx::Collector->list( config => $config, logger => $logger );

    Mx::Mason::Config->setup_callbacks( config => $config, logger => $logger );
}

my $ah = HTML::Mason::ApacheHandler->new(
  comp_root => '/lch/fxclear/' . $ENV{MXUSER} . '/projects/xx_apache/xml',
  data_dir  => '/lch/fxclear/data/' . $ENV{MXENV} . '/xx_apache/data/mason',
  preloads  => [ '/mx/login.html' ]
);

sub handler {
    my ($r) = @_;

    return $ah->handle_request($r);
}
