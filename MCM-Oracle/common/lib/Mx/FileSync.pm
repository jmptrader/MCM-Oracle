package Mx::FileSync;

use strict;
use warnings;

use Mx::Log;
use Mx::Util;
use IO::File;
use File::Find;
use String::CRC::Cksum qw( cksum );
use Carp;


#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $self = { logger => $logger };

    my $target;
    unless ( $target = $args{target} ) {
        $logger->logdie("missing argument in initialisation of FileSync (target)");
    }
    $self->{target} = $target;

    unless ( substr( $target, 0, 1 ) eq '/' ) {
        $logger->logdie("target $target must be fully qualified");
    }

    $target =~ s/\/$//;

    unless ( -e $target ) {
        $logger->logdie("target $target not found");
    }

    my $recursive = $self->{recursive} = ( exists $args{recursive} ) ? $args{recursive} : 0;

    $self->{analyzed} = 0;

    $logger->debug("FileSync initialized (target: $target - recursive: $recursive)");

    bless $self, $class;
}

#-----------#
sub analyze {
#-----------#
    my ( $self ) = @_;


    my $target    = $self->{target};
    my $recursive = $self->{recursive};

    $self->{files}    = {};
    $self->{nr_files} = 0;

    my $target_is_directory = -d $target;

    my @list = ();
    if ( $target_is_directory ) {
        if ( $recursive ) {
            find( sub { push @list, $File::Find::name if -f $_ }, $target ); 
        }
        else {
            unless ( opendir DIR, $target ) {
                $self->{logger}->logdie("unable to access $target: $!");
            }

            while ( my $file = readdir(DIR) ) {
                $file = $target . '/' . $file;

                next unless -f $file;

                push @list, $file;
            }

            closedir(DIR);
        }
    }
    else {
        push @list, $target;
    }

    my $nr_files = $self->{nr_files} = @list;

    while ( my $file = shift @list ) {
        my $key = $file;

        $key =~ s/^$target\/// if $target_is_directory;

        $self->{files}->{$key} = _analyze_file( $file );
    }

    $self->{analyzed} = 1;

    $self->{logger}->info("$target analyzed, $nr_files file(s) in total");
}

#-----------#
sub compare {
#-----------#
    my ( $self, $remote, %args ) = @_;


    unless ( ref( $self ) eq ref( $remote ) ) {
        $self->{logger}->logdie("argument must be a FileSync object");
    }

    unless ( $self->{analyzed} && $remote->{analyzed} ) {
        $self->{logger}->logdie("both filesyncs must be analyzed before compare");
    }

    my $local_files     = $self->{files};
    my $local_nr_files  = $self->{nr_files};

    my $remote_files    = $remote->{files};
    my $remote_nr_files = $remote->{nr_files};

    my $check_perms = $self->{check_perms} = ( exists $args{check_perms} ) ? $args{check_perms} : 0;

    my @differences = (); my $remote_nr_files_covered = 0;

    while ( my ( $local_file, $local_data ) = each %{$local_files} ) {
        if ( my $remote_data = $remote_files->{$local_file} ) {
            $remote_nr_files_covered++;

            next if ( $local_data->[0] == $remote_data->[0] && $local_data->[1] == $remote_data->[1] && ( ! $check_perms || ( $local_data->[2] == $remote_data->[2] ) ) );

            push @differences, [ $local_file, $local_data, $remote_data ];

        }
        else {
            push @differences, [ $local_file, $local_data, undef ];
        }
    }

    if ( $remote_nr_files_covered < $remote_nr_files ) {
        while ( my ( $remote_file, $remote_data ) = each %{$remote_files} ) {
            next if exists $local_files->{$remote_file};
            
            push @differences, [ $remote_file, undef, $remote_data ];
        }
    }

    return @differences;
}

#--------------------#
sub print_difference {
#--------------------#
    my ( $class, $difference ) = @_;


    printf "\n%s:\n", $difference->[0];
    printf "[source] %s\n", _print_data( $difference->[1] );
    printf "[target] %s\n", _print_data( $difference->[2] );
}

#---------------#
sub _print_data {
#---------------#
    my ( $data ) = @_;

  
    return '-' unless $data;

    sprintf "size: %8s  checksum: %10s  permissions: %o  timestamp: %s", Mx::Util->separate_thousands( $data->[0] ), $data->[1], $data->[2], scalar( localtime( $data->[3] ) );
}

#-----------------#
sub _analyze_file {
#-----------------#
    my ( $path ) = @_;


    my ( $mode, $size, $mtime ) = (stat($path))[2,7,9];

    my $perms = $mode & 07777;

    my $checksum = -1;
    if ( my $fh = IO::File->new( $path, 'r' ) ) {
        $checksum = cksum( $fh );
        $fh->close();
    }

    return [ $size, $checksum, $perms, $mtime ];
}

1;
