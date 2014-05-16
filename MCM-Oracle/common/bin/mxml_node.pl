#!/usr/bin/env perl

use warnings;
use strict; 

use Mx::Config;
use Mx::Log;
use Mx::Account;
use Mx::Oracle;
use Mx::DBaudit;
use Mx::SQLLibrary;
use Mx::MxML::Node;
use Mx::MxML::Task;
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
my $account = Mx::Account->new( name => $config->FIN_DBUSER, config => $config, logger => $logger );
 
#
# initialize the Sybase connection
#
my $oracle = Mx::Oracle->new( database => $config->DB_FIN, username => $account->name, password => $account->password, logger => $logger, config => $config );

#
# setup the SQL library
#
my $sql_library = Mx::SQLLibrary->new( file => $config->SQLLIBRARY, logger => $logger );
 
#
# open the DB connection
#
$oracle->open();

my $count = 0; my %seen = ();
my $workflow_query;
if ( $create ) {
    #
    # truncate the old table
    #
    $db_audit->cleanup_mxml_nodes();

    my $task_query;
    unless ( $task_query = $sql_library->query('retrieve_mxml_tasks') ) {
        $logger->logdie('query with as key retrieve_mxml_tasks cannot be retrieved from the library');
    }

    my $link_query;
    my $nodename_query;
    my $sheetname_query;
    my $task_cfg_query;

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

    unless ( $task_cfg_query = $sql_library->query('retrieve_mxml_task_config') ) {
        $logger->logdie('query with as key retrieve_mxml_task_config cannot be retrieved from the library');
    }

    my $result;
    unless ( $result = $oracle->query( query => $task_query ) ) {
        $logger->logdie("cannot retrieve the MxML task list");
    }

    while ( my ( $taskname, $xml, $compressed, $tasktype, $workflow_id, $sheetname_id ) = $result->next ) {
        my $sheetresult = $oracle->query( query => $sheetname_query, values => [ $sheetname_id ] );
        my $sheetname = $sheetresult->nextref->[0];

        my $workflow = translate_workflow_id( $workflow_id );

        #
        # filter out the pretrade nodes
        #
        next unless $workflow;
        next unless exists $Mx::MxML::Node::WORKFLOWS{$workflow};

        $db_audit->insert_mxml_task(
          taskname  => $taskname,
          tasktype  => $tasktype,
          sheetname => $sheetname,
          workflow  => $workflow,
          status    => $Mx::MxML::Task::STATUS_UNKNOWN
        );

        # 
        # convert hex to ascii
        #
        #$xml =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;

        if ( $compressed > 0 ) {
            my $fh  = IO::String->new( $xml );
            my $zip = Archive::Zip->new();
            $zip->readFromFileHandle( $fh );
            my ( $member ) = $zip->members();
            $xml = $zip->contents( $member );
        }

        $xml =~ s/wf://g;

        my $twig = XML::Twig->new();
        $twig->parse( $xml ); 

        if ( my $InputNode = $twig->root->first_child( "taskInputNodes" )->first_child( "taskNodes" ) ) {
            process_node( $InputNode, 'I', $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query );
        }

        if ( my $OutputNode = $twig->root->first_child( "taskOutputNodes" )->first_child( "taskNodes ") ) {
            process_node( $OutputNode, 'O', $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query );
        }

        if ( $tasktype eq 'ImportFileSystemV2' ) {
            if ( my $result2 = $oracle->query( query => $task_cfg_query, values => [ $taskname ] ) ) {
                my ( $xml, $compressed ) = $result2->next;

                #$xml =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;

                if ( $compressed > 0 ) {
                    my $fh  = IO::String->new( $xml );
                    my $zip = Archive::Zip->new();
                    $zip->readFromFileHandle( $fh );
                    my ( $member ) = $zip->members();
                    $xml = $zip->contents( $member );
                }

                my $xp = XML::XPath->new( xml => $xml );

                my $error_dir; my $received_dir;

                my $set1 = $xp->find('/TaskConfiguration/PropertyGroup[@name="General"]/Property[@name="Error directory"]');
                if ( $set1->size() == 1 ) {
                    $error_dir = $set1->get_node(1)->string_value;
                }

                my $set2 = $xp->find('/TaskConfiguration/PropertyGroup[@name="General"]/Property[@name="Received directory"]');
                if ( $set2->size() == 1 ) {
                    $received_dir = $set2->get_node(1)->string_value;
                }

                $db_audit->insert_mxml_directories( taskname => $taskname, error => $error_dir, received => $received_dir );
            }
        }
    }

    $logger->info("$count nodes inserted");
}

if ( $update ) {
    my ( $nodes_ref, $tasks_ref ) = Mx::MxML::Node->retrieve_all( logger => $logger, config => $config, db_audit => $db_audit );
    Mx::MxML::Node->update_nr_messages( logger => $logger, oracle => $oracle, library => $sql_library, nodes => $nodes_ref );
    Mx::MxML::Node->update_proc_time( logger => $logger, oracle => $oracle, library => $sql_library, nodes => $nodes_ref ) if $timings;
    Mx::MxML::Node->audit( logger => $logger, db_audit => $db_audit, nodes => $nodes_ref );
}

$oracle->close();

exit 0;


#----------------#
sub process_node {
#----------------#
    my ( $node, $in_out, $taskname, $tasktype, $sheetname, $workflow, $link_query, $nodename_query ) = @_;


    foreach my $element ( $node->children( "taskNode" ) ) {
        my $nodeids;
        if ( my $el = $element->first_child( "taskNodeFilterCode" ) ) {
            $nodeids = $el->text;
        }
        else {
            next;
        }

        my $noderesult = $oracle->query( query => $nodename_query, values => [ $nodeids, $taskname ] ); 
        my $nodename   = $noderesult->nextref->[0];

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
                my $result = $oracle->query( query => $link_query, values => [ $taskname, $nodename ] ); 
                @target_tasks = map { $_->[0] } $result->all_rows if $result;

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
        unless ( $result = $oracle->query( query => $workflow_query, values => [ $id ] ) ) {
            $logger->error("cannot retrieve workflow with id $id");
            return;
        }

        $WORKFLOWS{$id} = $result->nextref->[0];
    }

    return $WORKFLOWS{$id};
}

