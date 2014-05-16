package Mx::TWS::Streams;

# Fields
# ...
#

use strict;
use warnings;
use Carp;
use Mx::TWS::Nodes;
use Mx::TWS::Stream;
use Time::localtime;

use constant EXITCODE => 0;

my @dependencies;
my @streams;
my %selection;
my %status;
my $business_date;
my $config;
my $db_audit;
my $logger;
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
  
  initialize();
  bless $self, $class;
}

#--------------#
sub initialize {
#--------------#
 $logger->debug("initialize");  
 $nodes = Mx::TWS::Nodes->new(logger => $logger); 
 get_data(); 
 $nodes->set_nodes(nodes => \@streams);
 $nodes->set_predecessors(dependencies => \@dependencies);
 $nodes->set_successors(dependencies => \@dependencies); 
 $nodes->set_depth();  
 set_streams();   
}

#--------#
sub get {
#--------# 
  $logger->debug("get");    
  my ($class, %args) = @_;  
  $business_date= $args{business_date}; 
  my $stream_id = $args{stream_id};
 if (defined $business_date) {
 } else {
  my $tm = localtime;
  $business_date = sprintf("%04d%02d%02d", $tm->year+1900,($tm->mon)+1, $tm->mday);  
 }

 foreach my $stream (@streams) {  
  if ($stream->{id} eq $stream_id) {
   $stream->update(business_date => $business_date); 
   return $stream;
  }  
 }
}

#------------#
sub get_data {
#------------#
 $logger->debug("get_data");  
 @streams = $db_audit->retrieve_tws_streams();
 @dependencies = $db_audit->retrieve_tws_stream_dependencies();
}

#--------------------#
sub get_dependencies {
#--------------------#
 $logger->debug("get_dependencies");  
 return \@dependencies;
}

#-------------#
sub get_depth {
#-------------#
 $logger->debug("get_depth");  
 return $nodes->get_depth_counter();
}

#---------------#
sub get_streams {
#---------------#
 $logger->debug("get_streams");  
 return \@streams;
}

#--------#
sub list {
#--------# 
  $logger->debug("list");    
  my ($class, %args) = @_;  
  $business_date = $args{business_date}; 
  my $stream_id = $args{stream_id};
  %selection = ();
 if (defined $business_date) {
 } else {
  my $tm = localtime;
  $business_date = sprintf("%04d%02d%02d", $tm->year+1900,($tm->mon)+1, $tm->mday);  
 } 

 my @selected_streams=();   
 if ($nodes->get_nodes(key => $stream_id)) {
  set_status();
  $selection{$stream_id} = "selected";
  set_predecessors_selection($stream_id);
  set_successors_selection($stream_id);
  foreach my $stream (@streams) {  
   if ($selection{$stream->{id}}) {
    if (length($status{$stream->{id}}) gt 0) {
     $stream->set_status(status => $status{$stream->{id}});          
    }
    push @selected_streams, $stream;
   }
  }  
 } else {  
   if ((rindex $stream_id, "*") > -1) {
    set_status();
    $stream_id =~ s/\*//g; 
   foreach my $stream (@streams) {  
    if ((rindex $stream->{id}, $stream_id) > -1) {
                                 if (length($status{$stream->{id}}) gt 0) {
      $stream->set_status(status => $status{$stream->{id}});          
     }
     push @selected_streams, $stream;
    }
   }   
  }   
 }
 return @selected_streams; 
}  

#------------------------------#
sub set_predecessors_selection {
#------------------------------# 
 my $key = $_[0];
 my $predecessors = $nodes->get_predecessors(key => $key);  
 if ($predecessors) {
  my @item = split(/,/, $predecessors);
   foreach my $item (@item) {
    $selection{$item} = "selected";
    set_predecessors_selection($item);
  }  
 }
}

#---------------------------#
sub set_predecessors_status {
#---------------------------# 
 my $key = $_[0];
 my $predecessors = $nodes->get_predecessors(key => $key);  
 if ($predecessors) {
  my @item = split(/,/, $predecessors);
  foreach my $item (@item) {
   	if (length($status{$item}) eq 0) {
      $status{$item} = EXITCODE;
      set_predecessors_status($item);
    } 
  }  
 }
}

#--------------#
sub set_status {
#--------------# 
 $logger->debug("set_status"); 
 %status = ();  
 my $prev_sched_jobstream = "";
 my $prev_mx_scriptname = "";
 my @sessions = $db_audit->retrieve_sessions6(business_date => $business_date);  
 foreach my $session (@sessions) {    
  my $curr_sched_jobstream = substr($session->{sched_jobstream},1);
  my $curr_mx_scriptname = substr($session->{mx_scriptname},1);  
  if ($prev_sched_jobstream eq $curr_sched_jobstream) {
     if ($prev_mx_scriptname eq $curr_mx_scriptname) {
        $status{$curr_sched_jobstream} = $session->{exitcode};     
     } else {
       if ($status{$curr_sched_jobstream} eq EXITCODE) {
          $status{$curr_sched_jobstream} = $session->{exitcode};     
       }
     }
  } else {
    $status{$curr_sched_jobstream} = $session->{exitcode};       
    set_predecessors_status($curr_sched_jobstream);
  }

  $prev_sched_jobstream = $curr_sched_jobstream;  
  $prev_mx_scriptname = $curr_mx_scriptname;    
 }
}
 
#---------------#
sub set_streams {
#---------------# 
 $logger->debug("set_streams");  
 @streams = ();
 my %depth = $nodes->get_depth();
 foreach my $key (sort {$depth{$a} cmp $depth{$b} } keys %depth) {
  my $node = $nodes->get_nodes(key => $key);   
  my $predecessors = $nodes->get_predecessors(key => $key);  
  my $successors = $nodes->get_successors(key => $key); 
  my $stream = Mx::TWS::Stream->new(config => $config, 
               logger => $logger, 
               db_audit => $db_audit, 
               id => $key, 
               node => $node,
               predecessors => $predecessors, 
               successors => $successors, 
               depth => $depth{$key}); 
   push @streams, $stream;
 }  
} 

#----------------------------#
sub set_successors_selection {
#----------------------------# 
  my $key = $_[0];
 my $successors = $nodes->get_successors(key => $key);  
 if ($successors) {
  my @item = split(/,/, $successors);
   foreach my $item (@item) {
    $selection{$item} = "selected";
    set_successors_selection($item);
  }  
 }
}

###
1
