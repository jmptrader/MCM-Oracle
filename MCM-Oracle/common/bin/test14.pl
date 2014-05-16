#!/usr/bin/env perl

use warnings;
use strict; 

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Sybase;
use Mx::DBaudit;
use Mx::SQLLibrary;
use Mx::MxML::Node;
use Getopt::Long;
use Archive::Zip;
use XML::Twig;
use XML::XPath;
use IO::String;

my %WORKFLOWS  = ();

#---------#
sub usage {
#---------#
    print <<EOT

Usage: mxml_node.pl [ -create ] [ -update [ -timings ] ] [ -help ]

 -create      Create the node translation table
 -update      Update the node translation table with the number of messages
 -timings     Update the node translation table with processing time info also
 -help        Display this text

EOT
;
    exit;
}


#
# store away the commandline arguments for later reference
#
my $args = "@ARGV";

#
# process the commandline arguments
#
my ($create, $update, $timings);

GetOptions(
    'create!'    => \$create,
    'update!'    => \$update,
    'timings!'   => \$timings,
    'help!'      => \&usage,
);

unless ( $create or $update ) {
    usage();
}

#
# read the configuration files
#
my $config = Mx::Config->new();
 
#
# initialize logging
#
my $logger = Mx::Log->new( directory => $config->LOGDIR, keyword => 'mxml_node' );

$logger->info("refreshing MxML node table");

my $db_audit = Mx::DBaudit->new( config => $config, logger => $logger );

#
# setup the Sybase account
#
my $account = Mx::Account->new( name => $config->MX_DBUSER, config => $config, logger => $logger );
 
#
# initialize the Sybase connection
#
my $sybase  = Mx::Sybase->new( dsquery => $config->DSQUERY, database => $config->DB_NAME, username => $account->name, password => $account->password, error_handler => 1, logger => $logger, config => $config );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
 
#
# open the Sybase connection
#
$sybase->open();

my $count = 0; my %seen = ();
my $workflow_query;
if ( $create ) {
    #
    # truncate the old table
    #
#    $db_audit->cleanup_mxml_nodes();


    my $task_query;
    unless ( $task_query = $sql_library->query('retrieve_mxml_tasks') ) {
        $logger->logdie('query with as key retrieve_mxml_tasks cannot be retrieved from the library');
    }

    my $link_query;
    my $nodename_query;
    my $sheetname_query;

    unless ( $link_query = $sql_library->query('retrieve_mxml_link') ) {
        $logger->logdie('query with as key retrieve_mxml_link cannot be retrieved from the library');
    }

    unless ( $workflow_query = $sql_library->query('retrieve_workflow_code') ) {
        $logger->logdie('query with as key retrieve_workflow_code cannot be retrieved from the library');
    }

    unless ( $nodename_query = $sql_library->query('retrieve_node_name') ) {
        $logger->logdie('query with as key retrieve_nodename cannot be retrieved from the library');
    }

    unless ( $sheetname_query = $sql_library->query('retrieve_sheet_name') ) {
        $logger->logdie('query with as key retrieve_sheetname cannot be retrieved from the library');
    }

    my $result;
    unless ( $result = $sybase->query( query => $task_query ) ) {
        $logger->logdie("cannot retrieve the MxML task list");
    }

    foreach my $row ( @{$result} ) {
        my ( $taskname, $xml, $compressed, $tasktype, $workflow_id, $sheetname_id ) = @{$row};

        my $sheetresult = $sybase->query( query => $sheetname_query, values => [ $sheetname_id ] );
        my $sheetname      = $sheetresult->[0][0]; 

        my $workflow = translate_workflow_id( $workflow_id );

        # 
        # convert hex to ascii
        #
        $xml =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;

        if ( $compressed > 0 ) {
            my $fh  = IO::String->new( $xml );
            my $zip = Archive::Zip->new();
            $zip->readFromFileHandle( $fh );
            my ( $member ) = $zip->members();
            $xml = $zip->contents( $member );
        }
	 
        $xml =~ s/wf://g;

        if ( $tasktype eq 'ImportFileSystemV2' ) {
            my $cfg_query = "select XML from MXMLEX_TASK_CFG_TABLE where STM_CODE = ?";
            my $result = $sybase->query( query => $cfg_query, values => [ $taskname ] );
            if ( $result ) {
                my $xml = $result->[0][0];
                $xml =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;
                my $fh  = IO::String->new( $xml );
                my $zip = Archive::Zip->new();
                $zip->readFromFileHandle( $fh );
                my ( $member ) = $zip->members();
                $xml = $zip->contents( $member );
                my $xp = XML::XPath->new( xml => $xml );
                my $set = $xp->find('/TaskConfiguration/PropertyGroup[@name="General"]/Property[@name="Error directory"]');
                if ( $set->size() == 1 ) {
                    my $error_dir = $set->get_node(1)->string_value;
                    print $dir, "\n";
                }
            }
        }

        next;

        my $twig = XML::Twig->new();
        $twig->parse( $xml ); 

        if ( my $InputNode = $twig->root->first_child( "taskInputNodes" )->first_child( "taskNodes" ) ) {
            process_node( $InputNode, 'I', $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query );
        }

        if ( my $OutputNode = $twig->root->first_child( "taskOutputNodes" )->first_child( "taskNodes ") ) {
            process_node( $OutputNode, 'O', $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query );
        }
    }

    $logger->info("$count nodes inserted");
}

if ( $update ) {
    my ( $nodes_ref, $tasks_ref ) = Mx::MxML::Node->retrieve_all( logger => $logger, config => $config, db_audit => $db_audit );
    my %nodes = %{$nodes_ref};
    Mx::MxML::Node->update_nr_messages( logger => $logger, sybase => $sybase, library => $sql_library, nodes => \%nodes );
    Mx::MxML::Node->update_proc_time( logger => $logger, sybase => $sybase, library => $sql_library, nodes => \%nodes ) if $timings;
    Mx::MxML::Node->audit( logger => $logger, db_audit => $db_audit, nodes => \%nodes );
}

$sybase->close();

exit 0;


#----------------#
sub process_node {
#----------------#
    my ( $node, $in_out, $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query ) = @_;


    foreach my $element ( $node->children( "taskNode" ) ) {
        my $nodeids   = $element->first_child( "taskNodeFilterCode" )->text;

        $logger->info( "nodeids = $nodeids" );
        $logger->info( "taskname = $taskname" );

        my $noderesult = $sybase->query( query => $nodename_query, values => [ $nodeids, $taskname ] ); 
        #my $nodename   = $element->first_child( "taskNodeCode" )->text;
        my $nodename   = $noderesult->[0][0];

        $logger->info( "nodename = $nodename" );

        $nodeids =~ s/^##//;
        $nodeids =~ s/##/ /g;

        my @nodelist = split " ", $nodeids;
 
        foreach my $nodeid ( @nodelist ) {
            my $key = $nodeid . '_' . $in_out;
            next if $seen{$key};

            my $target_task; my @target_tasks;
            if ( $in_out eq 'I' ) {
                $target_task = $taskname;
            }
            else {
                my $result = $sybase->query( query => $link_query, values => [ $taskname, $nodename ] ); 
                @target_tasks = map { $_->[0] } @{$result} if $result;

                if ( @target_tasks == 1 ) {
                    $target_task = shift @target_tasks;
                }
            }

            $db_audit->insert_mxml_node (
              id          => $nodeid,
              nodename    => $nodename,
              in_out      => $in_out,
              taskname    => $taskname,
              tasktype    => $tasktype,
              sheetname   => $sheetname,
              workflow    => $workflow,
              target_task => $target_task
            );

            foreach $target_task ( @target_tasks ) {
                $db_audit->insert_mxml_link (
                  id          => $nodeid,
                  target_task => $target_task
                );
            }

            $seen{$key}++;
            $count++;
        }
    }
}


#-------------------------#
sub translate_workflow_id {
#-------------------------#
    my ( $id ) = @_;


    unless ( exists $WORKFLOWS{$id} ) {
        my $result;
        unless ( $result = $sybase->query( query => $workflow_query, values => [ $id ] ) ) {
            $logger->error("cannot retrieve workflow with id $id");
            return;
        }

        $WORKFLOWS{$id} = $result->[0][0];
    }

    return $WORKFLOWS{$id};
}

