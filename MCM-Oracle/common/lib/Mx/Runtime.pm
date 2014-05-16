package Mx::Runtime;

use strict;
use warnings;

use Mx::Log;
use Mx::DBaudit;
use Date::Calc qw(:all);
use Carp;
use Data::Dumper;


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $self = {};

    my $logger = $args{logger} or croak 'no logger defined.';

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in initialisation of runtime (db_audit)");
    }

    my $scriptname;
    unless ( $scriptname = $self->{scriptname} = $args{scriptname} ) {
        $logger->logdie("missing argument in initialisation of runtime (scriptname)");
    }

    my $scripttype;
    unless ( $scripttype = $self->{scripttype} = $args{scripttype} ) {
        $logger->logdie("missing argument in initialisation of runtime (scripttype)");
    }

    my $runtype = $self->{runtype} = $args{runtype};
    my $entity  = $self->{entity}  = $args{entity};

    my @rows = $db_audit->retrieve_sessions9( scriptname => $scriptname, scripttype => $scripttype, runtype => $runtype, entity => $entity );

    my $total_duration = 0; my $total_cpu_seconds = 0; my $total_vsize = 0; my $nr_total_runs = 0; my $nr_failures = 0; my $lowest_date = 99999999; my $highest_date = 0;

    foreach my $row ( @rows ) {
        my $id            = $row->[0];
        my $starttime     = $row->[1];
        my $endtime       = $row->[2];
        my $exitcode      = $row->[3];
        my $cpu_seconds   = $row->[4];
        my $vsize         = $row->[5];
        my $business_date = $row->[6];

        if ( $self->{$business_date} ) {
            next if $self->{$business_date}->{id} > $id;
        }

        if ( $business_date < $lowest_date ) {
            $lowest_date = $business_date;
        }

        if ( $business_date > $highest_date ) {
            $highest_date = $business_date;
        }

        $nr_failures++ if ( ! defined $exitcode or $exitcode != 0 );

        my $duration;
        if ( $starttime && $endtime ) {
            $duration = $endtime - $starttime;
            $total_duration    += $duration;
            $total_cpu_seconds += $cpu_seconds;
            $total_vsize       += $vsize;
            $nr_total_runs++;
        }
        elsif ( ! $exitcode ) {
            $exitcode = 999;
            $nr_failures++;
        } 

        $self->{$business_date} = { id => $id, duration => $duration, exitcode => $exitcode, cpu_seconds => $cpu_seconds, vsize => $vsize };
    }

    $self->{nr_total_runs}   = $nr_total_runs;
    $self->{nr_failures}     = $nr_failures;
    $self->{avg_duration}    = ( $nr_total_runs ) ? int( $total_duration    / $nr_total_runs ) : 0;
    $self->{avg_cpu_seconds} = ( $nr_total_runs ) ? int( $total_cpu_seconds / $nr_total_runs ) : 0;
    $self->{avg_vsize}       = ( $nr_total_runs ) ? int( $total_vsize       / $nr_total_runs ) : 0;
    $self->{lowest_date}     = $lowest_date;
    $self->{highest_date}    = $highest_date;

    bless $self, $class;
}

#--------#
sub list {
#--------#
    my ( $class, %args ) = @_;


    my @runtimes;

    my $logger = $args{logger} or croak 'no logger defined.';

    my $db_audit;
    unless ( $db_audit = $args{db_audit} ) {
        $logger->logdie("missing argument in runtime list (db_audit)");
    }

    my $scripttype;
    unless ( $scripttype = $args{scripttype} ) {
        $logger->logdie("missing argument in runtime list (scripttype)");
    }

    my @scripttypes = ( ref($scripttype) eq 'ARRAY' ) ? @{$scripttype} : ( $scripttype );

    my $runtype;
    unless ( $runtype = $args{runtype} ) {
        $logger->logdie("missing argument in runtime list (runtype)");
    }

    my @runtypes = ( ref($runtype) eq 'ARRAY' ) ? @{$runtype} : ( $runtype );

    my @rows = $db_audit->retrieve_sessions8( scripttypes => \@scripttypes, runtypes => \@runtypes );

    my $lowest_date = 99999999; my $highest_date = 0;
    foreach my $row ( @rows ) {
        my $scriptname  = $row->[0];
        my $scripttype  = $row->[1];
        my $runtype     = $row->[2];
        my $entity      = $row->[3];

        if ( my $runtime = Mx::Runtime->new( scriptname => $scriptname, scripttype => $scripttype, runtype => $runtype, entity => $entity, db_audit => $db_audit, logger => $logger ) ) {
            push @runtimes, $runtime;

            if ( $runtime->{lowest_date} < $lowest_date ) {
                $lowest_date = $runtime->{lowest_date};
            }

            if ( $runtime->{highest_date} > $highest_date ) {
                $highest_date = $runtime->{highest_date};
            }
        }
    }

    my @dates = ( $lowest_date );

    my $date = $lowest_date;
    while ( $date < $highest_date ) {
        my ( $year, $month, $day ) = $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/;
        my ( $next_year, $next_month, $next_day ) = Add_Delta_Days( $year, $month, $day, 1 );
        $date = sprintf "%04d%02d%02d", $next_year, $next_month, $next_day;
        push @dates, $date;
    }

    foreach my $runtime ( @runtimes ) {
        $runtime->{dates} = \@dates;
    }

    return @runtimes;
}

#--------------#
sub scriptname {
#--------------#
    my ( $self ) = @_;


    return $self->{scriptname};
}

#--------------#
sub scripttype {
#--------------#
    my ( $self ) = @_;


    return $self->{scripttype};
}

#----------#
sub entity {
#----------#
    my ( $self ) = @_;


    return $self->{entity};
}

#-----------#
sub runtype {
#-----------#
    my ( $self ) = @_;


    return $self->{runtype};
}

#-----------------#
sub nr_total_runs {
#-----------------#
    my ( $self ) = @_;


    return $self->{nr_total_runs};
}

#---------------#
sub nr_failures {
#---------------#
    my ( $self ) = @_;


    return $self->{nr_failures};
}

#----------------#
sub avg_duration {
#----------------#
    my ( $self ) = @_;


    return $self->{avg_duration};
}

#-------------------#
sub avg_cpu_seconds {
#-------------------#
    my ( $self ) = @_;


    return $self->{avg_cpu_seconds};
}

#-------------#
sub avg_vsize {
#-------------#
    my ( $self ) = @_;


    return $self->{avg_vsize};
}

#---------#
sub dates {
#---------#
    my ( $self ) = @_;


    return @{$self->{dates}};
}

#------#
sub id {
#------#
    my ( $self, $date ) = @_;


    if ( $self->{$date} ) {
        return $self->{$date}->{id};
    }
}

#------------#
sub exitcode {
#------------#
    my ( $self, $date ) = @_;


    if ( $self->{$date} ) {
        return $self->{$date}->{exitcode};
    }
}

#------------#
sub duration {
#------------#
    my ( $self, $date ) = @_;


    if ( $self->{$date} ) {
        if ( $self->{$date}->{exitcode} ) {
            return  wantarray() ? ( 'FAIL', 'FAIL' ) : 'FAIL'; 
        }
         
        my $duration = $self->{$date}->{duration};

        if ( wantarray() ) {
            my $avg_duration = $self->{avg_duration};
            my $avg_delta = ( $avg_duration ) ? int( ( $duration - $avg_duration ) / $avg_duration * 100 ) : 0;
            return( $duration, $avg_delta );
        }
        else {
            return $duration;
        }
    }
}

#---------------#
sub cpu_seconds {
#---------------#
    my ( $self, $date ) = @_;


    if ( $self->{$date} ) {
        if ( $self->{$date}->{exitcode} ) {
            return  wantarray() ? ( 'FAIL', 'FAIL' ) : 'FAIL'; 
        }

        my $cpu_seconds = $self->{$date}->{cpu_seconds};

        if ( wantarray() ) {
            my $avg_cpu_seconds = $self->{avg_cpu_seconds};
            my $avg_delta = ( $avg_cpu_seconds ) ? int( ( $cpu_seconds - $avg_cpu_seconds ) / $avg_cpu_seconds * 100 ) : 0;
            return( $cpu_seconds, $avg_delta );
        }
        else {
            return $cpu_seconds;
        }
    }
}

#---------#
sub vsize {
#---------#
    my ( $self, $date ) = @_;


    if ( $self->{$date} ) {
        if ( $self->{$date}->{exitcode} ) {
            return  wantarray() ? ( 'FAIL', 'FAIL' ) : 'FAIL'; 
        }

        my $vsize = $self->{$date}->{vsize};

        if ( wantarray() ) {
            my $avg_vsize = $self->{avg_vsize};
            my $avg_delta = ( $avg_vsize ) ? int( ( $vsize - $avg_vsize ) / $avg_vsize * 100 ) : 0;
            return( $vsize, $avg_delta );
        }
        else {
            return $vsize;
        }
    }
}


1;
