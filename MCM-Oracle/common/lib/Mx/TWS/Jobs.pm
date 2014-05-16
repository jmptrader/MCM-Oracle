package Mx::TWS::Jobs;

# Fields
# ...
#

use strict;
use warnings;
use Carp;
use Mx::TWS::Job;
use Mx::TWS::Nodes;
use Time::localtime;

my @jobs;
my @dependencies;
my $config;
my $db_audit;
my $logger;
my $stream_id;
my $nodes;

#-------#
sub new {
#-------#
  my ($class, %args) = @_;
  my $self = {};
  $logger = $args{logger} or croak "missing argument in initialisation (logger)";	
  unless ( $config = $args{config} ) {
    $logger->logdie("missing argument in initialisation (config)");
  }
  unless ( $db_audit = $args{db_audit} ) {
    $logger->logdie("missing argument in initialisation (db_audit)");
  }
  unless ( $stream_id = $args{stream_id} ) {
    $logger->logdie("missing argument in initialisation (stream_id)");
  }  	
  initialize();
  bless $self, $class;
}

#--------#
sub get {
#--------#	
 	$logger->debug("get");		  
  my ($class, %args) = @_; 	
  my $job_id = $args{job_id};

	foreach my $job(@jobs) {	 
		if ($job->{id} eq $job_id) {
			  my $business_date = $args{business_date};
				$job->update(stream_id => $stream_id, business_date => $business_date); 
				return $job;
		}		
	}
}

#--------------#
sub initialize {
#--------------# 
	$logger->debug("initialize");		
	$nodes = Mx::TWS::Nodes->new(logger => $logger);	
	get_data();	
	$nodes->set_nodes(nodes => \@jobs);
	$nodes->set_predecessors(dependencies => \@dependencies);
	$nodes->set_successors(dependencies => \@dependencies);	
	$nodes->set_depth();		
	set_jobs();			
}


#------------#
sub get_data {
#------------#
	$logger->debug("get_data");		
	@jobs = $db_audit->retrieve_tws_stream_jobs(stream_id => $stream_id);
	@dependencies = $db_audit->retrieve_tws_stream_jobs_dependencies(stream_id => $stream_id);
}

#-------------#
sub get_depth {
#-------------#
	$logger->debug("get_depth");		
	return $nodes->get_depth_counter();
}

#--------#
sub list {
#--------#	
	$logger->debug("list");		
  my ($class, %args) = @_;	
  my $business_date= $args{business_date};	
	if (defined $business_date) {
	} else {
		my $tm = localtime;
		$business_date = sprintf("%04d%02d%02d", $tm->year+1900,($tm->mon)+1, $tm->mday);		
	}

	foreach my $job (@jobs) {	 
		$job->update(stream_id => $stream_id, business_date => $business_date); 
	}			
	return @jobs;  
}		


#------------#
sub set_jobs {
#------------#	
	$logger->debug("set_jobs");		
	@jobs = ();
	my %depth = $nodes->get_depth();
	foreach my $key (sort {$depth{$a} cmp $depth{$b} } keys %depth) {
		my $predecessors = $nodes->get_predecessors(key => $key);		
		my $successors = $nodes->get_successors(key => $key);				
		my $node = $nodes->get_nodes(key => $key);					
		my $job = Mx::TWS::Job->new(config => $config, 
															logger => $logger, 
															db_audit => $db_audit, 
															id => $key, 
															node => $node,															
															predecessors => $predecessors, 
															successors => $successors, 
															depth => $depth{$key});	
 		push @jobs, $job;
	}		
}	

###
1
