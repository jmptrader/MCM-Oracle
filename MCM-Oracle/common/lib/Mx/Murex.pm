package Mx::Murex;

use strict;
use warnings;

use Carp;
use Mx::Oracle;
use Mx::SQLLibrary;
use Mx::Log;
use Mx::Util;
use File::Basename;
use File::chmod;
use Time::Local;
use Date::Calc qw( Day_of_Week Days_in_Month Add_Delta_Days );

our %DATE_FIELDS = (
    FO   => { table => 'TRN_DSKD_DBF', date_column => 'M_DATE',     select_column => 'M_LABEL' },
    MO   => { table => 'TRN_PLCC_DBF', date_column => 'M_DATE',     select_column => 'M_LABEL' },
    BO   => { table => 'TRN_PC_DBF',   date_column => 'M_DATE',     select_column => 'M_LABEL' },
    ACC  => { table => 'TRN_ENTD_DBF', date_column => 'M_ACC_DATE', select_column => 'M_LABEL' },
    ENT  => { table => 'TRN_ENTD_DBF', date_column => 'M_PCG_DATE', select_column => 'M_LABEL' },
    CONS => { table => 'TRN_ENTD_DBF', date_column => 'M_CNS_DATE', select_column => 'M_LABEL' }, 
);

my %UNION_CALENDARS = ();

#
# Function used to return the Murex date.
# Arguments:
# type:       type of Murex date, 6 possible values: 'FO', 'MO', 'BO', 'ACC', 'ENT' or 'CONS'
# label:      name of the desk, pc, plcc or entity
# calendar:   calendar to use for the shifter
# oracle:     an opened Mx::Oracle object
# library:    a Mx::SQLLibrary object
# logger:     the usual Mx::Log object
#
#--------#
sub date {
#--------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    #
    # check the arguments
    #
    my @required_args = qw(type label oracle library);
    foreach my $arg (@required_args) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument ($arg)");
        }
    }

    my $oracle = $args{oracle};
    unless ( ref($oracle) eq 'Mx::Oracle' ) {
        $logger->logdie('the oracle argument is not a Mx::Oracle object');
    }

    my $library = $args{library};
    unless ( ref($library) eq 'Mx::SQLLibrary' ) {
        $logger->logdie('the library argument is not a Mx::SQLLibrary object');
    }

    my $query;
    unless ( $query = $library->query('murex_dates') ) {
        $logger->logdie('query with as key murex_dates cannot be retrieved from the library');
    }

    my ($table, $date_column, $select_column, $select_value);
    if ( my $ref = $DATE_FIELDS{$args{type}} ) {
        $table         = $ref->{table};
        $date_column   = $ref->{date_column};
        $select_column = $ref->{select_column};
        $select_value  = $args{label};
    }
    else {
        $logger->logdie('wrong type specified: ', $args{type});
    }

    #
    # we have to substitute the placeholders
    # 
    $query =~ s/__DATE_COLUMN__/$date_column/g;
    $query =~ s/__TABLE__/$table/g;

    my $result;
    $query =~ s/__SELECT_COLUMN__/$select_column/g;
    unless ( $result = $oracle->query( query => $query, values => [ $select_value ], quiet => 1 ) ) {
        $logger->logdie('cannot determine ', $args{type}, ' date');
    }

    my $date = $result->nextref->[0];

    $logger->debug($args{type}, ' date is ', $date || '');

    return $date;
}

#--------------#
sub is_holiday {
#--------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    #
    # check the arguments
    #
    my @required_args = qw(date calendar oracle library);
    foreach my $arg ( @required_args ) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument for is_holiday ($arg)");
        }
    }

    my $oracle   = $args{oracle};
    my $library  = $args{library};
    my $calendar = $args{calendar};
    my $date     = $args{date};

    my @dates;
    if ( ref($date) eq 'ARRAY' ) {
        @dates = @{$date};
    }
    else {
        @dates = ( $date );
    }

    my $nr_holidays = 0;
    foreach my $date ( @dates ) {
        #
        # first check if we are in a weekend
        #
        if ( $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
            my $year  = $1;
            my $month = $2;
            my $day   = $3;
            $month--;
            my $epoch = timelocal( 0, 0, 0, $day, $month, $year );
            my $weekday = (localtime( $epoch ))[6];
            if ( $weekday == 0 or $weekday == 6 ) {
                $nr_holidays++;
                $logger->debug("$date is a weekend day");
                next;
            }
        }
        else {
            $logger->logdie("$date is not a valid date");
        }

        #
        # check if the calendar is a combined calendar
        #
        my $is_union;
        if ( exists $UNION_CALENDARS{$calendar} ) {
            $is_union = $UNION_CALENDARS{$calendar};
        }
        else {
            my $query = $library->query('calendar_isunion');

            my $result;
            unless ( $result = $oracle->query( query => $query, values => [ $calendar ], quiet => 1 ) ) {
                $logger->logdie("cannot determine calendar type for calendar $calendar");
            }

            $is_union = $UNION_CALENDARS{$calendar} = $result->nextref->[0];
        }

        my $query_name = ( $is_union ) ? 'calendar_isholiday_2' : 'calendar_isholiday_1';

        my $query = $library->query( $query_name );

        my $result;
        unless ( $result = $oracle->query( query => $query, values => [ $calendar, $date, $date, $date ], quiet => 1 ) ) {
            $logger->logdie("cannot determine if $date is a holiday according to calendar $calendar");
        }

        my $is_holiday = $result->nextref->[0];

        if ( $is_holiday ) {
            $nr_holidays++;
            $logger->debug("$date is a holiday according to calendar $calendar");
        }
        else {
            $logger->debug("$date is not a holiday according to calendar $calendar");
        }
    }

    return $nr_holidays;
}

#--------------#
sub date_shift {
#--------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    #
    # check the arguments
    #
    my @required_args = qw(date shift calendar oracle library);
    foreach my $arg ( @required_args ) {
        unless ( $args{$arg} ) {
            $logger->logdie("missing argument for date_shift ($arg)");
        }
    }

    my $oracle   = $args{oracle};
    my $library  = $args{library};
    my $calendar = $args{calendar};
    my $date     = $args{date};
    my $shift    = $args{shift};

    my $year; my $month; my $day;
    if ( $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
        $year  = $1;
        $month = $2;
        $day   = $3;
    }
    else {
        $logger->logdie("$date is not a valid date");
    }

    my $delta = ( $shift > 0 ) ? 1 : -1;
    my $days_shifted = 0; my $final_date = $date;

    while ( $days_shifted != $shift ) {
        ( $year, $month, $day ) = Add_Delta_Days( $year, $month, $day, $delta );

        $final_date = sprintf "%04d%02d%02d", $year, $month, $day;

        my $is_holiday = Mx::Murex->is_holiday( date => $final_date, calendar => $calendar, library => $library, oracle => $oracle, logger => $logger );

        $days_shifted += $delta unless $is_holiday;
    }

    return $final_date;
}

#-----------------#
sub plcc_calendar {
#-----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $plcc;
    unless ( $plcc = $args{plcc} ) {
        $logger->logdie("missing argument (plcc)");
    }

    my $query = $library->query('plcc_calendar');

    my $result;
    unless ( $result = $oracle->query( query => $query, values => [ $plcc ], logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve calendar for PLCC $plcc");
    }

    my $calendar = $result->nextref->[0];

    $logger->debug("the calendar of PLCC $plcc is $calendar");

    return $calendar;
}

#---------------------#
sub previous_eom_date {
#---------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $plcc;
    unless ( $plcc = $args{plcc} ) {
        $logger->logdie("missing argument (plcc)");
    }

    my $calendar = Mx::Murex->plcc_calendar( plcc => $plcc, oracle => $oracle, library => $library, logger => $logger );

    my $plcc_date = Mx::Murex->date( type => 'MO', label => $plcc, calendar => $calendar, oracle => $oracle, library => $library, logger => $logger, config => $config );

    my $year; my $month; my $day;
    if ( ( $year, $month, $day ) = $plcc_date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
        $month--;
        if ( $month == 0 ) {
            $month = 12;
            $year--;
        }
        $day = Days_in_Month( $year, $month );
    }
    else {
        $logger->logdie("date $plcc_date for PLCC $plcc is not a valid date");
    }

    while ( $day > 0 ) {
        my $date = $year;
        $date .= sprintf "%02d", $month;
        $date .= sprintf "%02d", $day;

        if ( Mx::Murex->is_holiday( date => $date, calendar => $calendar, oracle => $oracle, library => $library, logger => $logger, config => $config ) ) {
            $day--;
            next;
        }

        $logger->debug("previous EOM date for PLCC $plcc is $date");
        return $date;
    }

    $logger->logdie("no previous EOM date could be determined voor PLCC $plcc");
}

#-----------------#
sub next_eom_date {
#-----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $plcc;
    unless ( $plcc = $args{plcc} ) {
        $logger->logdie("missing argument (plcc)");
    }

    my $calendar = Mx::Murex->plcc_calendar( plcc => $plcc, oracle => $oracle, library => $library, logger => $logger );

    my $plcc_date = Mx::Murex->date( type => 'MO', label => $plcc, calendar => $calendar, oracle => $oracle, library => $library, logger => $logger, config => $config );

    my $year; my $month; my $day;
    if ( ( $year, $month, $day ) = $plcc_date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
        $day = Days_in_Month( $year, $month );
    }
    else {
        $logger->logdie("date $plcc_date for PLCC $plcc is not a valid date");
    }

    while ( $day > 0 ) {
        my $date = $year;
        $date .= sprintf "%02d", $month;
        $date .= sprintf "%02d", $day;

        if ( Mx::Murex->is_holiday( date => $date, calendar => $calendar, oracle => $oracle, library => $library, logger => $logger, config => $config ) ) {
            $day--;
            next;
        }

        $logger->debug("next EOM date for PLCC $plcc is $date");
        return $date;
    }

    $logger->logdie("no next EOM date could be determined voor PLCC $plcc");
}

#----------------#
sub businessdate {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger};

    my $config;
    unless ( $config = $args{config} ) {
        my $message = "missing argument (config)";
        $logger ? $logger->logdie( $message ) : croak( $message );
    }

    my $datefile = $config->retrieve('DATEFILE');

    my $fh;
    unless ( $fh = IO::File->new( $datefile, '<' ) ) {
        my $message = "cannot open $datefile: $!";
        $logger ? $logger->logdie( $message ) : croak( $message );
    }

    my $date = <$fh>;

    $fh->close();

    chomp($date);

    if ( $date =~ /^\d{8}$/ ) {
        return $date;
    }
    else {
        my $message = "$datefile does not contain a valid business date ($date)";
        $logger ? $logger->logdie( $message ) : croak( $message );
    }
}

#----------------#
sub calendardate {
#----------------#
    my ( $class, $time ) = @_;

    
    $time = $time || time();
    my ($day, $month, $year) = ( localtime( $time ) )[3..5];
    return sprintf "%04s%02s%02s", $year + 1900, ++$month, $day;
}

#---------------------#
sub roll_businessdate {
#---------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    my $skip_saturday = $args{skip_saturday};

    $logger->info("rolling business date");


    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $date = Mx::Murex->businessdate( logger => $logger, config => $config );

    $logger->info("current business date: $date");

    my ( $year, $month, $day );
    unless ( ( $year, $month, $day ) = $date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/ ) {
        $logger->logdie("$date is not a valid business date");
        return;
    }

    my $weekday = Day_of_Week( $year, $month, $day );

    my $shifter = 1;
    if ( $weekday == 5 && $skip_saturday ) {
        $shifter = 3;
        $logger->info("Saturday will be skipped");
    }
    elsif ( $weekday == 6 ) {
        $shifter = 2;
    }
    elsif ( $weekday == 7 ) {
        $logger->warn("today is a Sunday, doing nothing");
        return;
    }

    my ( $next_year, $next_month, $next_day ) = Add_Delta_Days( $year, $month, $day, $shifter );

    my $next_date = sprintf "%04d%02d%02d", $next_year, $next_month, $next_day;

    $logger->info("next business date: $next_date");

    my $datefile = $config->retrieve('DATEFILE');

    my $fh;
    unless ( $fh = IO::File->new( $datefile, '>' ) ) {
        $logger->logdie("cannot open $datefile: $!");
        return;
    }

    printf $fh "$next_date\n";

    $fh->close();

    $logger->info("business date updated");

    return 1;
}

#--------------#
sub batch_nick {
#--------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $hostname = Mx::Util->hostname;

    my @app_servers = $config->retrieve_as_array( 'APP_SRV' );
    my @batch_nicks = $config->retrieve_as_array( 'BATCH_NICK' );

    while ( my $app_server = shift @app_servers ) {
        my $nick = shift @batch_nicks;

        if ( Mx::Util->hostname( $app_server ) eq $hostname && $nick ) {
            $logger->info("nick to use: $nick");

            return $nick;
        }
    }

    $logger->logdie("unable to determine batch nick for server $hostname");
}

#----------------#
sub session_nick {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $hostname = Mx::Util->hostname;

    my @app_servers   = $config->retrieve_as_array( 'APP_SRV' );
    my @session_nicks = $config->retrieve_as_array( 'SESSION_NICK' );

    while ( my $app_server = shift @app_servers ) {
        my $nick = shift @session_nicks;

        if ( Mx::Util->hostname( $app_server ) eq $hostname && $nick ) {
            $logger->info("nick to use: $nick");

            return $nick;
        }
    }

    $logger->logdie("unable to determine session nick for server $hostname");
}

#---------------------------#
sub get_last_accounting_run {
#---------------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument (entity)");
    }

    my $accountingfile = $config->retrieve('PROJECT_RUNDIR') . '/last_acc_run_' . $entity;

    my $fh;
    unless ( $fh = IO::File->new( $accountingfile, '<' ) ) {
        $logger->error("cannot open $accountingfile: $!");
        return;
    }

    my $date = <$fh>;

    $fh->close();

    chomp($date);

    return $date; 
}

#---------------------------#
sub set_last_accounting_run {
#---------------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument (entity)");
    }

    my $date;
    unless ( $date = $args{date} ) {
        $logger->logdie("missing argument (date)");
    }

    my $accountingfile = $config->retrieve('PROJECT_RUNDIR') . '/last_acc_run_' . $entity;

    my $fh;
    unless ( $fh = IO::File->new( $accountingfile, '>' ) ) {
        $logger->error("cannot open $accountingfile: $!");
        return;
    }

    printf $fh "$date\n";

    $fh->close();

    return 1;
}

#------------#
sub fo_desks {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('fo_desks');

    my $result;
    unless ( $result = $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve list of FO desks");
    }

    return map { $_->[0] } $result->all_rows;
}

#---------------#
sub plc_centers {
#---------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('plc_centers');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve list of PLCC's");
    }

    return map { $_->[0] } $result->all_rows;
}

#----------------#
sub proc_centers {
#----------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('proc_centers');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve list of Processing centers");
    }

    return map { $_->[0] } $result->all_rows;
}

#------------#
sub entities {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('entities');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve list of entities");
    }

    return map { $_->[0] } $result->all_rows;
}

#---------------#
sub entity_sets {
#---------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('entity_sets');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve list of entity sets");
    }

    return map { $_->[0] } $result->all_rows;
}

#------------------------#
sub entity_to_entity_set {
#------------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }
   
    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument (entity)");
    }

    my $query = $library->query('entity_to_entity_set');

    my $result;
    unless ( $result =  $oracle->query( query => $query, values => [ $entity ], logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot translate an entity ($entity) to its entity set");
    }

    return $result->nextref->[0];
}

#----------------------#
sub entity_set_to_plcc {
#----------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }
   
    my $entity_set;
    unless ( $entity_set = $args{entity_set} ) {
        $logger->logdie("missing argument (entity_set)");
    }

    my $query = $library->query('entity_set_to_plcc');

    my $result;
    unless ( $result =  $oracle->query( query => $query, values => [ $entity_set ], logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot translate an entity set ($entity_set) to its plcc");
    }

    return $result->nextref->[0];
}

#------------------#
sub closedown_date {
#------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $entity;
    unless ( $entity = $args{entity} ) {
        $logger->logdie("missing argument (entity)");
    }

    my $query = $library->query('closedown_date');

    my $result;
    unless ( $result =  $oracle->query( query => $query, values => [ $entity ], logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve closedown date");
    }

    return $result->nextref->[0];
}

#-------------------------#
sub nr_uncommitted_trades {
#-------------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('nr_uncommitted_trades');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve number of uncommitted trades");
    }

    return $result->nextref->[0];
}

#-------------------------#
sub nr_uncommitted_mktops {
#-------------------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('nr_uncommitted_mktops');

    my $result;
    unless ( $result =  $oracle->query( query => $query, logger => $logger, quiet => 1 ) ) {
        $logger->logdie("cannot retrieve number of uncommitted market operations");
    }

    return $result->nextref->[0];
}

#
# This class method looks up all the templates that are defined in the configuration file,
# and installs all these templates while performing all the necessary substitutions, as defined
# in the configuration file.
#
#---------------------#
sub install_templates {
#---------------------#
    my ($class, %args) = @_;

    my $logger = $args{logger} or croak 'no logger defined';
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }
    $logger->debug('scanning the configuration file for templates');
    my $templates_ref;
    unless ( $templates_ref = $config->TEMPLATES ) {
        $logger->logdie("cannot access the templates section in the configuration file");
    }
    foreach my $name ( keys %{$templates_ref} ) {
        $logger->debug("template '$name' found");
        my $template          = $config->retrieve("TEMPLATES.$name.template");
        my $target            = $config->retrieve("TEMPLATES.$name.target");
        my $executable        = $config->retrieve("TEMPLATES.$name.executable");
        my $substitutions_ref = $config->retrieve("TEMPLATES.$name.substitutions");
        my %substitutions;
        foreach my $placeholder ( keys %{$substitutions_ref} ) {
            my $value = $config->retrieve("TEMPLATES.$name.substitutions.$placeholder");
            $substitutions{$placeholder} = $value;
        }
        _install_template($logger, $template, $target, $executable, %substitutions);
    }
}

#---------------------#
sub _install_template {
#---------------------#
    my ($logger, $template, $target, $executable, %substitutions) = @_;

    $logger->debug("transforming template file $template into target file $target"); 
    #
    # check if the directory where the target resides exists, otherwise create it
    #
    my $dirname = dirname( $target );
    unless ( -d $dirname ) {
        unless ( Mx::Util->mkdir( directory => $dirname, logger => $logger ) ) {
            $logger->logdie("cannot create $dirname");
        }
    }
    my $fh_in; my $fh_out;
    unless ( $fh_in = IO::File->new( $template, '<' ) ) {
       $logger->logdie("cannot open template file $template");
    }
    unless ( $fh_out = IO::File->new( $target, '>' ) ) {
       $logger->logdie("cannot open target file $target");
    }
    while ( my $line = <$fh_in> ) {
INNER:  while ( $line =~ /(__[^_]\w+?[^_]__)/ ) {
            if ( exists $substitutions{$1} ) {
                $line = $` . $substitutions{$1} . $';
                last INNER if $substitutions{$1} =~ /^__.*__$/; # to avoid an endless loop if the substitution contains __ 
            }
            else {
                $logger->logdie("no substitution found for placeholder $1 in template file $template");
            }
        }
        print $fh_out $line;
    }
    $fh_in->close;
    $fh_out->close;
    #
    # check if the resulting file must be made executable
    # 
    if ( $executable ) {
        chmod( '+x', $target );
        $logger->debug("$target made executable"); 
    }
}

#------------------#
sub binary_version {
#------------------#
    my ( $class, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined.';
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }
    my $binary = $config->MXENV_ROOT . '/mx';
    unless ( -f $binary ) {
        $logger->error("cannot locate mx binary $binary");
        return;
    }
    unless ( open CMD, "/usr/bin/strings $binary | grep '^v3.1' |" ) {
        $logger->error("cannot check mx binary: $!");
        return;
    }
    my $version = <CMD>;
    close(CMD);
    $version =~ s/\s+$//;
    $version =~ s/^v//i;
    return $version;
}

#--------------#
sub db_version {
#--------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument (library)");
    }

    my $query = $library->query('murex_version');

    my $result = $oracle->query( query => $query, logger => $logger, quiet => 1 );

    return () unless $result;

    my ( $version, $build, $timestamp ) = $result->next;

    return ( version => $version, build => $build, timestamp => $timestamp );
}

1;

__END__

=head1 NAME

<Module::Name> - <One-line description of module's purpose>


=head1 VERSION

The initial template usually just has: 

This documentation refers to <Module::Name> version 0.0.1.


=head1 SYNOPSIS

    use <Module::Name>;
    

# Brief but working code example(s) here showing the most common usage(s)

    # This section will be as far as many users bother reading,
    # so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e., =head2, =head3, etc.).


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.

					    
=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT


A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.

					
=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.


=head1 AUTHOR

<Author name(s)>

