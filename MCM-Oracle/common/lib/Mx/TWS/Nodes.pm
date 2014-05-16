package Mx::TWS::Nodes;

# Fields
# ...
#

use strict;
use warnings;
use Carp;

my @dependencies;
my @nodes;
my %depth;
my %predecessors;
my %nodes;
my %successors;
my $depth_counter;
my $logger;

#-------#
sub new {
#-------#
  my ($class, %args) = @_;
  my $self = {};
  $logger = $args{logger} or croak "missing argument in initialisation (logger)"; 
  $logger->debug("TWS::Nodes"); 
  bless $self, $class;  
}

#-------------#
sub get_nodes {
#-------------#
  my ($class, %args) = @_; 
  my $key = $args{key}; 
  return $nodes{$key}; 
}
 
#--------------------#
sub get_predecessors {
#--------------------#
  my ($class, %args) = @_; 
  my $key = $args{key}; 
  return $predecessors{$key};
} 

#------------------#
sub get_successors {
#------------------#
  my ($class, %args) = @_; 
  my $key = $args{key}; 
  return $successors{$key};
} 

#-------------#
sub get_depth {
#-------------#
 $logger->debug("get_depth"); 
  return %depth;
}

#---------------------#
sub get_depth_counter {
#---------------------#
 $logger->debug("get_depth_counter"); 
  return $depth_counter;
}

#-------------#
sub set_depth {
#-------------#
 $logger->debug("set_depth"); 
 $depth_counter = 0;
 %depth = (); 
 my $depth_size = scalar keys %depth;
 my $nodes_size = scalar keys %nodes;   
 my $while_counter = 0;
 while ($depth_size ne $nodes_size && $while_counter < 25) {
  $while_counter++;
  $depth_counter++;
  while ((my $key, my $value) = each(%nodes)) {
   my $is_depth = 1;
   if ($depth{$key}) {
   } else {
    if ($predecessors{$key}) {
     my @item = split(/,/, $predecessors{$key});   
      foreach my $item (@item) {
       if ($depth{$item}) {
        if ($depth{$item} eq $depth_counter) {
         $is_depth = 0;
        }
       } else {
        $is_depth = 0;
       }        
      }
    } else {
     
    }
    if ($is_depth) {
     $depth{$key} = $depth_counter;
    }
   }      
  }
  $depth_size = scalar keys %depth;
 }
 return \%depth;
}

#-------------#
sub set_nodes {
#-------------#
 $logger->debug("set_nodes"); 
  my ($class, %args) = @_; 
  @nodes = @{$args{nodes}};
 %nodes = ();
 foreach my $node (@nodes) {   
  if ($nodes{$node->{id}}) {
   $nodes{$node->{id}}->{multiplicator} = "*";
  } else {
   $nodes{$node->{id}} = $node;
   $nodes{$node->{id}}->{multiplicator} = "1";
  }
 }
}

#--------------------#
sub set_predecessors {
#--------------------#
 $logger->debug("set_predecessors"); 
  my ($class, %args) = @_; 
  %predecessors = ();  
 @dependencies = @{$args{dependencies}};
 foreach my $dependency(@dependencies) {  
  my $slash_offset = (rindex $dependency->{reference_id},"/") + 1;
  $dependency->{reference_id} = substr $dependency->{reference_id}, $slash_offset;
  $dependency->{dependent_id} = substr $dependency->{dependent_id}, $slash_offset;    
  if ($predecessors{$dependency->{dependent_id}}) { 
   my $found = 0; 
   my @item = split(/,/, $predecessors{$dependency->{dependent_id}});
    foreach my $item (@item) {
     if ($item eq $dependency->{reference_id}) {
      $found = 1;
     }
   }    
   if ($found) {       
   } else {
    $predecessors{$dependency->{dependent_id}} = $predecessors{$dependency->{dependent_id}} . "," . $dependency->{reference_id};    
   }
  } else {
   $predecessors{$dependency->{dependent_id}} = $dependency->{reference_id};
  }
 }
}

#------------------#
sub set_successors {
#------------------#
 $logger->debug("set_successors"); 
  my ($class, %args) = @_; 
  %successors = ();  
 @dependencies = @{$args{dependencies}};
 foreach my $dependency(@dependencies) {
  my $slash_offset = (rindex $dependency->{reference_id},"/") + 1;
  $dependency->{reference_id} = substr $dependency->{reference_id}, $slash_offset;
  $dependency->{dependent_id} = substr $dependency->{dependent_id}, $slash_offset;    
  if ($successors{$dependency->{reference_id}}) { 
   my $found = 0; 
   my @item = split(/,/, $successors{$dependency->{reference_id}});
    foreach my $item (@item) {
     if ($item eq $dependency->{dependent_id}) {
      $found = 1;
     }
   }    
   if ($found) {   
   } else {    
    $successors{$dependency->{reference_id}} = $successors{$dependency->{reference_id}} . "," . $dependency->{dependent_id};    
   }
  } else {
   $successors{$dependency->{reference_id}} = $dependency->{dependent_id};
  }
 }  
}

#
1
