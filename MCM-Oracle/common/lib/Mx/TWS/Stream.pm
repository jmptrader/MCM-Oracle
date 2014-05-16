package Mx::TWS::Stream;

# Fields
# ...
#

use strict;
use warnings;
use Carp;

use constant WAITING  		=> 1;
use constant NEEDS_VERIFICATION	=> 2;
use constant COMPLETED		=> 3;

my $config;
my $db_audit;
my $logger;
	

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
  unless ( $self->{id} = $args{id} ) {
      die("missing argument in initialisation of Mx::TWS::Job (id)");
  }    
  unless ( $self->{depth} = $args{depth} ) {
      die("missing argument in initialisation of Mx::TWS::Job for id $self->{id} (depth)");
  }    
	my $node = $args{node};  
	$self->{acceptance_server} = $node->{acceptance_server};		
	$self->{development_server} = $node->{development_server};			
	$self->{integration_server} = $node->{integration_server};
	$self->{priority} = $node->{priority};
	$self->{production_server} = $node->{production_server};	
	$self->{resource_name} = $node->{resource_name};	
	$self->{resource_value} = $node->{resource_value};		
	$self->{run} = $node->{run};	
	$self->{predecessors} = $args{predecessors};
  $self->{successors} = $args{successors};
  $self->{status} = WAITING;  
  
  bless $self, $class;
}

#-----------#
sub set_status {
#-----------#
  my ($self, %args) = @_;	
  my $status = $args{status};
  if ($status eq 0) {
	$status = COMPLETED;
  } else {
	$status = NEEDS_VERIFICATION;	
  }
  $self->{status}=$status; 
}

#-----------#
sub update {
#-----------#
  my ($self, %args) = @_;	
  my $business_date = $args{business_date};
  
  my @sessions = $db_audit->retrieve_sessions4(sched_jobstream => $self->{id}, business_date => $business_date); 
  
  my $status = WAITING;  
  if ($sessions[$#sessions]) {
		if ($sessions[$#sessions]->{exitcode} eq 0) {
			$status = COMPLETED;
		} else {
			$status = NEEDS_VERIFICATION;	
		}
	}	

	$self->{status}=$status;
}

###
1
