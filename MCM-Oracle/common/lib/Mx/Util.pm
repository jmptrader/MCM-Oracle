package Mx::Util;

use strict;

use Carp;
use Cwd;
use IO::File;
use File::Temp;
use File::Path qw( rmtree mkpath );
use Mx::Process;
use Time::Local;
use Sys::Hostname ();
use File::Find;
use Data::Dumper;
use Date::Calc qw( Add_Delta_Days );
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;


use constant TARCMD    => '/bin/tar';
use constant ZIPCMD    => '/bin/gzip';
use constant MOVECMD   => '/bin/mv';

#
# Class method to tar one or more directories/files into one tarfile, possibly specifying a list of directories/files to exclude.
# Arguments:
# tarfile:     name of the tarfile (string)
# workdir:     directory relative to which the tar must be taken (string)
# files:       list of directories/files to be tarred (array ref)
# excludelist: list of directories/files to exclude (array ref)
# logger:      the usual Mx::Log object
# config:      the usual Mx::Config object
#
#-------#
sub tar {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    $logger->debug('starting tar');

    my $config;
    unless ( $config = $args{config} ) {
        $logger->error('missing argument (config)');
        return;
    }

    #
    # check the tarfile argument
    #
    unless ( $args{tarfile} ) {
        $logger->error('no tarfile specified');
        return;
    }
    $logger->debug( 'tarfile: ', $args{tarfile} );

    #
    # check the files argument
    #
    unless ( $args{files} ) {
        $logger->error('no files specified');
        return;
    }
    unless ( ref( $args{files} ) eq 'ARRAY' ) {
        $logger->error("argument 'files' should be a reference to an array");
        return;
    }
    chomp( @{$args{files}} );
    my $files = join ' ', @{$args{files}};
    $logger->debug( 'files to be tarred: ', $files );

    #
    # check the workdir argument
    #
    unless ( $args{workdir} ) {
        $logger->error('no workdir specified');
        return;
    }
    $logger->debug( 'working directory: ', $args{workdir} );

    #
    # If an excludelist is specified (which should be a reference to an array of filenames),
    # we create a temporary file to store these filenames and supply this file as an argument to
    # the tar command. The temporary file will be put in /tmp, which shouldn't hurt as it will be
    # a small file, and is removed after the tar.
    #
    my $excludelist = '';
    if ( $args{excludelist} ) {
        unless ( ref( $args{excludelist} ) eq 'ARRAY' ) {
            $logger->error('excludelist should be a reference to an array');
            return;
        }
        my $tmpfile;
        unless ( $tmpfile = File::Temp->new( DIR => '/tmp', UNLINK => 0 ) ) {
            $logger->error('cannot create a temporary file: $!');
            return;
        }
        $excludelist = $tmpfile->filename();
        $logger->debug("temporary excludelist created ($excludelist)");
        foreach my $entry ( @{ $args{excludelist} } ) {
            chomp($entry);
            print $tmpfile $entry, "\n";
        }
    }

    #
    # cd to the workingdir
    #
    my $currentdir = cwd();
    unless ( chdir( $args{workdir} ) ) {
        unlink($excludelist) if $excludelist;
        $logger->error( 'cannot cd to workdir (', $args{workdir}, '): ', $! );
        return;
    }

    #
    # Build the tar command. We tar into a temporary .wait file which is then renamed.
    #
    my $command = TARCMD . ( ($excludelist) ? ' -cfX ' : ' -cf ' ) . $args{tarfile} . '.wait ' . $excludelist . ' ' . $files . ';' . MOVECMD . ' -f ' . $args{tarfile} . '.wait ' . $args{tarfile};

    #
    # Run the tar command.
    #
    if ( Mx::Process->run( command => $command, logger => $logger, config => $config ) ) {
        #
        # Check if the file exists and is not empty
        #
        unless ( -f $args{tarfile} && -s $args{tarfile} ) {
            unlink($excludelist) if $excludelist;
            chdir($currentdir);
            $logger->error( 'tarfile does not exist or is empty (', $args{tarfile}, ')' );
            return;
        }
    }
    else {
        $logger->error('tar failed');
        unlink($excludelist) if $excludelist;
        chdir($currentdir);
        return;
    }

    #
    # Cleanup.
    #
    unlink($excludelist) if $excludelist;
    chdir($currentdir);
    $logger->debug('tar succeeded');
    return 1;
}

#
# Class method to gzip a file. The file is not zipped in place, but instead a sourcefile and targetfile should be specified.
# Arguments:
# sourcefile: name of the file to be zipped
# targetfile: resultfile
# erase:      boolean indicating if the sourcefile must be removed after compression
# logger:     the usual Mx::Log object
# config:     the usual Mx::Config object
#
#------------#
sub compress {
#------------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined.';
    $logger->debug('starting compress');

    my $config;
    unless ( $config = $args{config} ) {
        $logger->error('missing argument (config)');
        return;
    }

    #
    # check the sourcefile argument
    #
    unless ( $args{sourcefile} ) {
        $logger->error('no source file specified');
        return;
    }
    $logger->debug( 'sourcefile: ', $args{sourcefile} );
    my $fh;
    unless ( $fh = IO::File->new( $args{sourcefile}, '<' ) ) {
        $logger->error( 'cannot open source file (', $args{sourcefile} );
        return;
    }
    $fh->close();

    #
    # check the targetfile argument
    #
    unless ( $args{targetfile} ) {
        $logger->error('no target file specified');
        return;
    }
    $logger->debug( 'targetfile: ', $args{targetfile} );

    #
    # build the zip command
    #
    my $command = ZIPCMD . ' -cf ' . $args{sourcefile} . ' > ' . $args{targetfile} . '.wait;' .  MOVECMD . ' -f ' . $args{targetfile} . '.wait ' . $args{targetfile};
    if ( Mx::Process->run( command => $command, logger => $logger, config => $config ) ) {
        #
        # Check if the file exists and is not empty
        #
        unless ( -f $args{targetfile} && -s $args{targetfile} ) {
            $logger->error( 'targetfile does not exist or is empty (', $args{targetfile}, ')' );
            return;
        }
    }
    else {
        $logger->error('compress failed');
        return;
    }

    $logger->debug('compress succeeded');

    if ( $args{erase} ) {
        if ( unlink( $args{sourcefile} ) ) {
            $logger->debug('sourcefile removed');
        }
        else {
            $logger->warn("cannot remove sourcefile: $?");
        }
    }

    return 1;
}

#
# Same method as the previous compress method, but in this case the gzip is started in the background, and the
# pid is returned.
#
#-----------------------#
sub background_compress {
#-----------------------#
    my ( $class, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined.';
    $logger->debug('starting background compress');
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument (config)');
    }
    #
    # check the sourcefile argument
    #
    unless ( $args{sourcefile} ) {
        $logger->error('no source file specified');
        return;
    }
    $logger->debug( 'sourcefile: ', $args{sourcefile} );
    unless ( my $fh = IO::File->new( $args{sourcefile}, '<' ) ) {
        $logger->error( 'cannot open source file (', $args{sourcefile} );
        return;
    }
    #
    # check the targetfile argument
    #
    unless ( $args{targetfile} ) {
        $logger->error('no target file specified');
        return;
    }
    $logger->debug( 'targetfile: ', $args{targetfile} );
    #
    # build the zip command
    #
    my $command = ZIPCMD . ' -cf ' . $args{sourcefile} . ' > ' . $args{targetfile} . '.wait;' . MOVECMD . ' ' . $args{targetfile} . '.wait ' . $args{targetfile};
    my( $process, $pid );
    if ( $process = Mx::Process->background_run( command => $command, logger => $logger, config => $config ) )
    {
       $pid = $process->pid;
        $logger->debug("background compress started (pid=$pid)");
    }
    else {
        $logger->error('background compress failed');
    }
    return $pid;
}

#
# Class method for extracting a compressed tarfile.
# Notice that it first cleans up the the work directory!
# Arguments:
# archive: name of the compressed tarfile
# workdir: directory where the extraction needs to take place
# logger:  the usual Mx::Log object
#
#-----------#
sub extract {
#-----------#
    my ( $class, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined.';
    $logger->debug('starting extract');
    my $config;
    unless ( $config = $args{config} ) {
        $logger->error('missing argument (config)');
        return;
    }
    #
    # check the archive argument
    #
    my $archive;
    unless ( $archive = $args{archive} ) {
        $logger->error('no archive specified');
        return;
    }
    unless ( -f $archive ) {
        $logger->error("archive $archive not found");
        return;
    }
    $logger->debug("archive: $archive");
    #
    # check the workdir argument
    #
    my $workdir;
    unless ( $workdir = $args{workdir} ) {
        $logger->error('no workdir specified');
        return;
    }
    $logger->debug("working directory: $workdir");
    #
    # cd to the workingdir
    #
    my $currentdir = cwd();
    unless ( chdir( $workdir ) ) {
        $logger->error("cannot cd to workdir ($workdir): $!");
        return;
    }
    #
    # clean up the work directory
    #
    Mx::Util->rmdir( directory => $workdir, logger => $logger );
    #
    # build the extract command
    #
    my $command = ZIPCMD . " -dc $archive|" . TARCMD . ' -xf -';
    unless ( Mx::Process->run( command => $command, logger => $logger, config => $config ) ) {
        chdir($currentdir);
        $logger->error('extract failed');
        return;
    }
    chdir($currentdir);
    $logger->debug('extract succeeded');
    return 1;
}

#-----------#
sub dirsize {
#-----------#
    my ( $class, %args ) = @_;

   
    my $logger = $args{logger} or croak 'no logger defined.';

    my $dir;
    unless ( $dir = $args{directory} ) {
        $logger->error("missing argument: directory");
        return;
    }

    unless ( -d $dir ) {
        $logger->error("$dir is not a directory");
        return;
    }

    my $size = 0;

    find sub { $size += -s }, ( $dir );

    return $size;
}

#---------#
sub rmdir {
#---------#
    my ( $class, %args ) = @_;

   
    my $logger = $args{logger} or croak 'no logger defined.';

    my $dir;
    unless ( $dir = $args{directory} ) {
        $logger->error("missing argument: directory");
        return;
    }

    $logger->debug("cleaning up $dir");

    my $rc = 1;
    my $currentdir = getcwd();
    chdir( '/' );

    my $error_ref;
    rmtree( $dir, { verbose => 0, keep_root => 1, error => $error_ref } );

    foreach my $error ( @{$error_ref} ) {
        my ($file, $message) = each %{$error};
        $file ||= 'general error';
        $logger->error("$file: $message");
        $rc = 0;
    }

    if( $args{remove} ){
        rmdir $dir || return 0;
        return $rc;
    }
    
    #
    # to be on the safe side
    #
    mkdir( $dir );

    chdir( $currentdir );

    $logger->debug("$dir cleaned up");

    return $rc;
}

#---------#
sub mkdir {
#---------#
    my ( $class, %args ) = @_;
   
    my $logger = $args{logger} or croak 'no logger defined.';
    my $dir;
    unless ( $dir = $args{directory} ) {
        $logger->error("missing argument: directory");
        return;
    }
    $logger->debug("creating $dir");
    my $rc = 1;
    my $error_ref;
    mkpath( $dir, { verbose => 0, error => $error_ref } );
    foreach my $error ( @{$error_ref} ) {
        my ($file, $message) = each %{$error};
        $file ||= 'general error';
        $logger->error("$file: $message");
        $rc = 0;
    }
    $logger->debug("$dir created");
    return $rc;
}

#
# unique filename based on time
#
#------------------#
sub unique_filename{
#------------------#
    my( $self, %args ) = @_;

    my $logger = $args{logger} or croak 'no logger defined';
    my $directory = $args{directory} || undef;
    $logger->logdie( "no directory defined" ) unless( $directory );
    $logger->logdie( "invalid directory" ) unless( -d $directory );
    my $pfx = lc( $args{prefix} ) || '';
    my $sfx = lc( $args{suffix} ) || '';
    for( $pfx, $sfx ){ s/[^\w\.\-]+//g };
    $pfx =~ s/\.*$/\./ if( $pfx );
    $sfx =~ s/^\.*/\./ if( $sfx );
     
    my $start = time;
    my $path;
    my $allow = $args{allow} || 30; # 30 second default
    while(1){
        sleep(1); # allow for multiple calls
        my $date = $self->epoch_to_iso( clock => 1, joiner => '.' );
        $path = $directory.'/'.$pfx.$date.$sfx;
        $logger->debug( "trying $path" );
        last if( CORE::mkdir( $path ) );
        if( time - $start > $allow ){
            $logger->logdie( "unique_filename function timed out" );
        }
    }
    CORE::rmdir( $path );
    return $path;
}

#------------#
sub hostname {
#------------#
    my ( $class, $hostname ) = @_;

   
    if ( $hostname ) {
        $hostname =~ s/\..+$//;
        return $hostname;
    }
    else {
        return Sys::Hostname::hostname();
    }
}

#--------#
sub trim {
#--------#
    my( $self, $str ) = @_;

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

#---------#
sub rtrim {
#---------#
    my( $self, $str ) = @_;
    
    $str =~ s/\s+$//;
    return $str;
}

#---------#
sub ltrim {
#---------#
    my( $self, $str ) = @_;
    
    $str =~ s/^\s+//;
    return $str;
}
#
#
#-------#
sub dump{
#-------#
    my( $self, %args ) = @_;

    unless( ref $args{ds} ){
        if( $args{logger} ){
            $args{logger}->dubug( "ds is not a reference" );
        }
        return;
    }
    if( $args{to_string} ){
        return Dumper $args{ds};
    }
    if( $args{term} ){
        print Dumper $args{ds};
    }
    if( $args{fn} ){ $args{fn} =~ s/[^\w\/\.]//g; }
    
    my( $fn )  = $args{fn} || $0 =~ /(\w+)\.pl$/;
    if( $args{logger} ){
        $args{logger}->debug( "Dumping data structure to $fn" );
    }
    open my $out, '>/tmp/'.$fn;
    print $out Dumper $args{ds};
    close $out;
}

#
# Date Class methods

#
# date format conversion
# arguments:
# $date    a date string in one of the formats covered below
# $format  (optional) specify the incoming format by keyword
# 
#----------------#
sub convert_date {
#----------------#
    my ( $self, $date, $format ) = @_;
    
    return undef unless $date;

    # already in iso format ?
    return $date if( $self->validate_iso_date( $date ) );
     
    # converts dates in the following formats to iso (i.e. YYYYMMDD)
    # mm/dd/yyyy hh:mm:ss
    # dd/mm/yy
    # dd/mm/yyyy
    # ddmmyy
    # ddmmyyyy
    # Sep 10 1996 12:00:00:000AM    (sybase)
    # April 30,2003                 (excel)
    # 27 February 2007              (excel)
    # YYYYMMDD HH:MM:SS             (excel)
    # 2007-May-01                   (yyyy_mmm_dd)
    # 

    unless( $format ){
        if( $date =~ /\// ){
            if( $date =~ / / ){ # 02/24/2002 12:00:00 AM
                $format = 'mm_dd_yyyy_time';
            }
            else{
                $format = $date =~ /\d{4}$/ ? 'dd_mm_yyyy' : 'dd_mm_yy';
            }
        }
        elsif( $date =~ / / ){
            if( $date =~ /\d{4}$/ ){
                $format = ( $date =~ /\,/ ) ? 'excel_a' : 'excel_b';
            }
            elsif( $date =~ s/ \d{2}\:\d{2}\:\d{2}// ){
                $format = 'excel_c';
            }
            else{
                $format = 'sybase';
            }
        }
        elsif ( $date =~ /\d{8}/ ){
            $format = 'ddmmyyyy';
        }
        elsif ( $date =~ /\d{6}/ ){
            $format = 'ddmmyy';
        }
        else{ # dunno!
            return undef;
        }
    }
  
    my ( $yr, $mth, $dom );
    my @months = qw ( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $month_m2d = sub{
        my $mth = shift;
        for( my $i=0; $i < scalar @months; $i++ ){
            if( $mth =~ /^$months[$i]/i ){
                $mth = ++$i;
                last;
            }
        }
        return $mth;
    };
    
    my %reformats = (
        'yyyy_mmm_dd' => sub{
            ( $yr, $mth, $dom ) = split( /\-/, $date );
            $mth = $month_m2d->( $mth );
        },
        'mm_dd_yyyy_time' => sub {
            $date =~ s/ .+$//;
            ( $mth, $dom, $yr ) = split( /\//, $date );
        },
        'dd_mm_yyyy' => sub {
            ( $dom, $mth, $yr ) = split( /\//, $date );
        },
        'dd_mm_yy' => sub {
            ( $dom, $mth, $yr ) = split /\//, $date;
            $yr = ( ( $yr > 50  ) ? '19' : '20' ).$yr;
        },
        'excel_a' => sub{
            ( $mth, $dom, $yr ) = split( /[ \,]+/, $date );
            $mth = $month_m2d->( $mth );
       },
        'excel_b' => sub{
            ( $dom, $mth, $yr ) = split( / +/, $date );
            $mth = $month_m2d->( $mth );
       },
        'excel_c' => sub{
            ( $yr, $mth, $dom ) = ( substr( $date, 0, 4 ), substr( $date, 4, 2 ), substr( $date, 6 ) );
        },
        'sybase' => sub {
            ( $mth, $dom, $yr ) = split / +/, $date;
            $mth = $month_m2d->( $mth );
       },
        'ddmmyyyy' => sub {
            ( $dom, $mth, $yr ) = ( substr( $date, 0, 2 ), substr( $date, 2, 2 ), substr( $date, 4 ) );
        },
        'ddmmyy' => sub {
            ( $dom, $mth, $yr ) = ( substr( $date, 0, 2 ), substr( $date, 2, 2 ), substr( $date, 4 ) );
            $yr = ( ( $yr > 50  ) ? '19' : '20' ).$yr;
        }
    );
    $reformats{$format}->();
    
    return wantarray ? ( $yr, $mth, $dom ) : sprintf( "%4d%02d%02d", $yr, $mth, $dom );
}

#---------------#
sub epoch_to_iso{
#---------------#
    my( $class, %args ) = @_;
    my $epoch = $args{epoch} || time;
    
    my( $sec, $min, $hr, $dom, $mth, $yr ) = ( localtime( $epoch ) )[ 0..5 ];
    $mth++;
    $yr += 1900;
    
    my $date = sprintf( "%04d%02d%02d", $yr, $mth, $dom );
    return $date unless( $args{clock} );

    my $j = $args{no_joiner} ? '' : ( $args{joiner} ) ? $args{joiner} : '';
    my $time = sprintf( "%02d$j%02d$j%02d", $hr, $min, $sec );
    
    return wantarray ? ( $date, $time ) : join( $j, $date, $time );
}

#---------------#
sub epoch_to_ddmmyy{
#---------------#
    my( $class, $epoch, $append_time ) = @_;
    $epoch ||= time;
    my( $min, $hr, $dom, $mth, $yr ) = ( localtime( $epoch ) )[ 1..5 ];
    $mth++;
    $yr -= 100;
    return $append_time ?  sprintf( "%02d%02d%02d.%02d.%02d", $dom, $mth, $yr, $hr, $min ) : sprintf( "%02d%02d%02d", $dom, $mth, $yr );
}

#---------------#
sub epoch_to_MurexTimestamp{
#---------------#
    my( $class, $epoch ) = @_;

    $epoch = time unless( $epoch );
    # RFDATE = DD/MM/YYYY
    # RFTIME = number of seconds since midnight
    my( $rfdate, $rftime );
    my( $sec, $min, $hr, $dom, $mth, $yr ) = ( localtime( $epoch ) )[ 0..5 ];
    $mth++;
    $yr += 1900;
    $rfdate = sprintf( "%04d%02d%02d", $yr, $mth, $dom );
    $rftime = $sec + ( $min * 60 ) + ( $hr * 3600 );
    return( $rfdate, $rftime );
}

#--------------------#
sub validate_iso_date{
#--------------------#
    my( $class, $date ) = @_;
    
    # check for a well formed date
    return unless( $date =~ /^\d{8}$/ );
    my( $yr, $mth, $dom ) = ( substr( $date, 0, 4 ), substr( $date, 4, 2 ), substr( $date, 6 ) );
    return unless( ( $dom > 0 ) && ( $dom < 32 ) );
    return unless( ( $mth > 0 ) && ( $mth < 13 ) );
    return unless( ( $yr > 1889 ) && ( $yr < 2117 ) ); # arbitrary range of years
    $mth--;
    return eval{ timelocal( 0, 0, 0, $dom, $mth, $yr ) } 
}

#--------------------#
sub roll_date_by_day {
#--------------------#
    my( $class, $days, $epoch ) = @_;
    $epoch ||= time;
    $days ||= 1;
    $epoch += $days * 86400;
}

#------------------#
sub murex_date_time{
#------------------#
    my( $class, $epoch ) = @_;

    $epoch = time unless( $epoch );
    # RFDATE = number of days since 1 Jan 1980
    # RFTIME = number of seconds since midnight
    my( $rfdate, $rftime );
    my $start = timelocal( 0, 0, 0, 1, 0, 80 );
    $rfdate = int( ( $epoch - $start ) / 86400 );
    my( $sec, $min, $hr ) = ( localtime( $epoch ) )[ 0..2 ];
    $rftime = $sec + ( $min * 60 ) + ( $hr * 3600 );
    return( $rfdate, $rftime );
}

#--------------#
sub date_range {
#--------------#
    my ( $class, $startdate, $enddate ) = @_;


    unless ( $startdate && $enddate ) {
        return();
    }

    if ( $startdate >= $enddate ) {
        return ();
    }

    my @range = (); my $date = $startdate;
    while ( $date < $enddate ) {
        push @range, $date;

        my ( $year, $month, $day )    = $date =~  /^(\d\d\d\d)(\d\d)(\d\d)$/;
        my ( $nyear, $nmonth, $nday ) = Add_Delta_Days( $year, $month, $day, 1 );
        $date = sprintf "%d%02d%02d", $nyear, $nmonth, $nday;
    }

    return @range;
}

#-------------------#
sub convert_seconds {
#-------------------#
    my ( $class , $seconds ) = @_;

    return undef unless defined $seconds;
    return $seconds unless $seconds =~ /^\d+$/;
    my $hours   = int( $seconds / 3600 );
    $seconds   %= 3600;
    my $minutes = int( $seconds / 60 );
    $seconds   %= 60;
    if ( wantarray() ) {
        return($hours, $minutes, $seconds)
    } else {
        sprintf "%02d:%02d:%02d", $hours, $minutes, $seconds;
    }
}

#-----------------------#
sub convert_seconds_inv {
#-----------------------#
    my ( $class, $interval ) = @_;

    if ( $interval =~ /^(\d\d):(\d\d):(\d\d)\.\d+$/ ) {
        return ( $1 * 3600 + $2 * 60 + $3 );
    }
}

#-----------------#
sub convert_bytes {
#-----------------#
    my ( $class , $bytes ) = @_;

    return undef unless defined $bytes;
    if ( $bytes >= 2**30 ) {
        return sprintf "%.2f GB", $bytes/(2**30);
    }
    elsif ( $bytes >= 2**20 ) {
        return sprintf "%.2f MB", $bytes/(2**20);
    }
    elsif ( $bytes >= 2**10 ) {
        return sprintf "%.2f KB", $bytes/(2**10);
    }
    else {
        return $bytes;
    }
}

#----------------#
sub convert_time {
#----------------#
    my ( $class, $time ) = @_;

    return undef unless $time;
    my ($sec, $min, $hour, $day, $month, $year) = ( localtime($time) )[ 0 .. 5 ];
    sprintf "%04d/%02d/%02d %02d:%02d:%02d", $year + 1900, $month + 1, $day, $hour, $min, $sec;
}

#----------------------#
sub convert_time_short {
#----------------------#
    my ( $class, $time ) = @_;


    return undef unless $time;

    my $microsec;
    if ( $time =~ /^(\d{10})(\d{3})$/ ) {
        $time     = $1;
        $microsec = $2;
    }

    my ($sec, $min, $hour) = ( localtime($time) )[ 0 .. 2 ];

    my $output = sprintf "%02d:%02d:%02d", $hour, $min, $sec;

    $output .= '.' . $microsec if defined $microsec;

    return $output;
}

#----------------------#
sub separate_thousands {
#----------------------#
    my ( $class, $number ) = @_;

    return undef unless defined $number;
    return $number unless $number =~ /^\d+$/;
    $number = reverse $number;
    $number =~ s/(\d{3})/$1,/g;
    $number = reverse $number;
    $number =~ s/^\,//;
    return $number;
}

#---------#
sub round {
#---------#
    my ( $class, $number, $places ) = @_;


    $places ||= 0;

    my $dec = 10 ** $places;
    my $sign = ( $number > 0 ) ? 1 : -1;

    $number = abs($number) * $dec + 0.5;
    $number =~ s/\..*$//;

    return $number * $sign / $dec;
}

#
# returns a hash containing all placeholders in the file and the number of occurences
#
#----------------#
sub placeholders {
#----------------#
    my ( $class, %args ) = @_;

    my %placeholders;
    my $logger = $args{logger} or croak 'no logger defined.';
    my $file;
    unless ( $file = $args{file} ) {
        $logger->error("missing argument: file");
        return;
    }
    my $fh;
    unless ( $fh = IO::File->new( $file, '<' ) ) {
        $logger->error("cannot open $file: $!");
        return;
    }
    while ( my $line = <$fh> ) {
        my @ph = $line =~ /\b(__[^_]\w+[^_]__)\b/g;
        foreach my $ph ( @ph ) {
            $placeholders{$ph}++;
        }
    }
    $fh->close();
    return %placeholders;
}

#
# removes duplicate entries in a path, e.g. LD_LIBRARY_PATH
#
#----------------#
sub cleanup_path {
#----------------#
    my ( $class, $path ) = @_;

    my @entries = split /:/, $path;
    my %seen = (); my @unique_entries = ();
    foreach my $entry ( @entries ) {
        $entry =~ s/\/$//;
        next unless -d $entry;
        next if $seen{$entry};
        $seen{$entry} = 1;
        push @unique_entries, $entry;
    }
    my $new_path = join ':', @unique_entries;
    return $new_path;
}

#
# Function to replace placeholders in a binary template file.
#
# Arguments:
# template   Full path to the template file
# cfghash    reference to a hash containing placeholders and corresponding replacement strings
# dummy      If this is set to true, no replacements will be done, only the number of placeholders found is returned
# 

#-----------------------#
sub process_bintemplate {
#-----------------------#
    my ( $class, %args ) = @_;

 
    my $recsize = 256;

    my $logger = $args{logger} or croak 'no logger defined.';

    my $template; 
    unless ( $template = $args{template} ) {
        $logger->logdie('missing argument (template)');
    }

    my $cfghash;
    unless ( $cfghash = $args{cfghash} ) {
        $logger->logdie('missing argument (cfghash)');
    }

    my $dummy = $args{dummy};

    unless ( $dummy ) {
        while ( my ( $key, $value ) = each %{$cfghash} ) {
            unless ( length($key) == length($value) ) {
                $logger->logdie("key ($key) and value ($value) do not have the same length");
            }
        }
    }

    unless ( open FH, "+<$template" ) {
       $logger->logdie("cannot open $template: $!");
    }

    my %replacements = (); my @window = (); my $record;
    while ( read( FH, $record, $recsize ) ) {
        push @window, $record;

        my $window = join '', @window;

        while ( my ( $key, $value ) = each %{$cfghash} ) {
            if ( $window =~ m/$key/ ) {
                my $position = tell(FH) - length($window) + length($`);
                $replacements{$position} = $value;
                $logger->debug("found string $key at position $position");
            }
        }

        if ( @window > 2 ) {
            shift @window;
        }
    }

    unless ( $dummy ) {
        while ( my ( $position, $value ) = each %replacements ) {
            $logger->debug("inserting string $value at position $position");
            seek( FH, $position, 0);
            print FH $value;
        }
    }

    close(FH);

    return scalar( keys %replacements );
}

#-----------------------#
sub process_xmltemplate {
#-----------------------#
    my ( $class, %args ) = @_;

 
    my $logger = $args{logger} or croak 'no logger defined.';

    my $config; 
    unless ( $config = $args{config} ) {
        $logger->logdie('missing argument (config)');
    }

    my $template;
    unless ( $template = $args{template} ) {
        $logger->logdie('missing argument (template)');
    }

    my $outputfile;
    unless ( $outputfile = $args{outputfile} ) {
        $logger->logdie('missing argument (outputfile)');
    }

    my $cfghash = $args{cfghash} || {};

    my ($in, $out);
    unless ( $in = IO::File->new( $template, '<' ) ) {
        $logger->error("cannot open $template: $!");
        return;
    }

    unless ( $out = IO::File->new( $outputfile, '>' ) ) {
        $logger->error("cannot open $outputfile: $!");
        return;
    }

    while ( my $line = <$in> ) {
        while ( $line =~ /__(\w+):(CRYPTED)?PASSWORD__/ ) {
            my $user    = $1;
            my $crypted = $2;
            my $account;
            unless ( $account = Mx::Account->new( name => $user, config => $config, logger => $logger ) ) {
                $logger->error("cannot retrieve account $user"); 
                return; 
            }
            my $password = ( $crypted ) ? $account->murex_password() : $account->password();
            $line =~ s/__$user:(CRYPTED)?PASSWORD__/$password/g;
        }
        while ( $line =~ /\b(__[^_]\$?\w+?[^_]__)\b/ ) {
            my $before = $`;
            my $ph     = $1;
            my $after  = $'; 
            if ( exists $cfghash->{$ph} ) {
                $line = $before . $cfghash->{$ph} . $after;
            }
            elsif ( $ph =~ /^__\$(.+)__$/ ) {
                my $cfg_param = $1;
                $line = $before . $config->retrieve( $cfg_param ) . $after;
            }
            else {
                $logger->error("no substitution found for placeholder $ph in template file $template");
                return;
            }
        }
        print $out $line;
    }

    $in->close;
    $out->close;

    return 1;
}

#
# convert "21/01/11 - 07:21:20" to epoch
#
#---------------------#
sub proctime_to_epoch {
#---------------------#
    my ( $class, $proctime ) = @_;


    my $epoch;
    if ( $proctime =~ /\b(\d+)\/(\d+)\/(\d+) - (\d+):(\d+):(\d+)\b/ ) {
        my $day   = $1;
        my $month = $2;
        my $year  = $3;
        my $hour  = $4;
        my $min   = $5;
        my $sec   = $6;
        $month--;
        $epoch = timelocal( $sec, $min, $hour, $day, $month, $year );
    }

    return $epoch;
}

1;


