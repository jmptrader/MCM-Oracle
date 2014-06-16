package Mx::MxUser;

use strict;
use warnings;

use Mx::Env;
use Mx::Config;
use Carp;


#
# Attributes:
#
# name:               login (label) 
# id:                 reference 
# description:        full name
# password:           encrypted version of the password
# mdate:              date when the password was last modified
# locked:             boolean indicating if the user is locked
# logger:             a Mx::Log instance
# config:             a Mx::Config instance
#


#-------#
sub new {
#-------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("missing argument in initialisation of user (name)");
    }
    $self->{name} = $name;

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }

    $self->{config}        = $config;
    $self->{oracle}        = $args{oracle};
    $self->{library}       = $args{library};
    $self->{id}            = $args{id};
    $self->{description}   = $args{description};
    $self->{password}      = $args{password};
    $self->{mdate}         = $args{mdate};
    $self->{locked}        = $args{locked};
    $self->{suspended}     = $args{suspended};
    $self->{suspend_start} = $args{suspend_start};
    $self->{suspend_end}   = $args{suspend_end};
    bless $self, $class;
}

#------------#
sub retrieve {
#------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';
    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $name;
    unless ( $name = $args{name} ) {
        $logger->logdie("missing argument in initialisation of user (name)");
    }

    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of user (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in initialisation of user (library)");
    }

    my $query = $library->query('retrieve_mx_user');

    my $result = $oracle->query( query => $query, values => [ $name ], quiet => 1 );

    if ( my ($id, $description, $password, $mdate, $locked, $suspended, $suspend_start, $suspend_end) = $result->next ) {
        return Mx::MxUser->new( name => $name, id => $id, description => $description, password => $password, mdate => $mdate, locked => $locked, suspended => $suspended, suspend_start => $suspend_start, suspend_end => $suspend_end, oracle => $oracle, library => $library, logger => $logger, config => $config );
    }
}

#----------------#
sub retrieve_all {
#----------------#
    my ($class, %args) = @_;


    my $logger = $args{logger} or croak 'no logger defined';

    my $self = {};
    $self->{logger} = $logger;

    #
    # check the arguments
    #
    my $config;
    unless ( $config = $args{config} ) {
        $logger->logdie("missing argument in initialisation of user (config)");
    }
    unless ( ref($config) eq 'Mx::Config' ) {
        $logger->logdie("config argument is not of type Mx::Config");
    }

    my $oracle;
    unless ( $oracle = $args{oracle} ) {
        $logger->logdie("missing argument in initialisation of user (oracle)");
    }

    my $library;
    unless ( $library = $args{library} ) {
        $logger->logdie("missing argument in initialisation of user (library)");
    }

    my $query = $library->query('retrieve_mx_users');

    my $result = $oracle->query( query => $query );

    my @list;
    while ( my ($id, $name, $description, $password, $mdate, $locked, $suspended, $suspend_start, $suspend_end) = $result->next ) {
        push @list, Mx::MxUser->new( name => $name, id => $id, description => $description, password => $password, mdate => $mdate, locked => $locked, suspended => $suspended, suspend_start => $suspend_start, suspend_end => $suspend_end, oracle => $oracle, library => $library, logger => $logger, config => $config );
    }

    return @list;
}

#-------------------#
sub update_password {
#-------------------#
    my ( $self, %args ) = @_;


    my $name = $self->{name};

    my $password;
    unless ( $password = $args{password} ) {
        $self->{logger}->logdie("missing argument in user password update (password)");
    }

    my $statement = $self->{library}->query('update_mx_user_password');

    if ( $self->{oracle}->do( statement => $statement, values => [ $password, $name ] ) ) {
        $self->{logger}->info("password of user $name updated");
        $self->{password} = $password;
        return 1;
    }
    else {
        $self->{logger}->error("password of user $name could not be updated");
        return 0;
    }
}

#-----------#
sub decrypt {
#-----------#
    my ( $class, $password ) = @_;


    my $ct_password = "";

    #
    # strip blanks from the end of the encrypted password
    #
    $password =~ s/\s+$//;
    #
    # now decrypt each character in a loop
    #
    for( my $pos = 0; $pos < length( $password ) / 4; $pos++ ) {
        #
        # get the 4-digit hexadecimal encryption
        #
        my $hexcode = substr( $password, $pos * 4, 4 );
        #
        # the decryption key depends on the position of the character
        #
        my $xor;
        if ( $pos % 7 == 0 ) {
            $xor = 0xc4;
        }
        elsif ( $pos % 7 == 1 ) {
            $xor = 0x75;
        }
        elsif ( $pos % 7 == 2 ) {
            $xor = 0x64;
        }
        elsif ( $pos % 7 == 3 ) {
            $xor = 0x13;
        }
        else {
            $xor = 0x93;
        }
        #
        # we have to convert the hexadecimal encrypted code to a long now for the xor
        #
        my $long = $xor ^ hex( "0x$hexcode" );
        #
        # now we generate a hexadecimal string from this one
        #
        my $encr_char = sprintf( "%02lx", $long );
        #
        # now swap the position of the characters
        #
        my $change_pos = substr( $encr_char, 1, 1 ) . substr( $encr_char, 0, 1 );
        #
        # this one has to be converted to the decrypted char now
        #
        $ct_password .= chr( hex( "0x$change_pos" ) );
    }
    return $ct_password;
}

#-----------#
sub encrypt {
#-----------#
    my ( $class, $password ) = @_;

    my $enc_password = "";
    
    #
    # strip blanks from the end of the cleartext password
    #
    $password =~ s/\s+$//;
    #
    # now encrypt each character in a loop
    #
    for ( my $pos = 0; $pos < length( $password ); $pos++ ) {
        my $char = substr( $password, $pos, 1 );
        #
        # get the ascii value of the character in hexadecimal format
        #
        my $hexcode = sprintf( "%02x", ord( $char ) );
        #
        # swap the position of the numbers
        #
        my $inv_hexcode = substr( $hexcode, 1, 1 ) . substr( $hexcode, 0, 1 );
        #
        # the encryption key depends on the position of the character
        #
        my $xor;
        if ( $pos % 7 == 0 ) {
            $xor = 0xc4;
        }
        elsif ( $pos % 7 == 1 ) {
            $xor = 0x75;
        }
        elsif ( $pos % 7 == 2 ) {
            $xor = 0x64;
        }
        elsif ( $pos % 7 == 3 ) {
            $xor = 0x13;
        }
        else {
            $xor = 0x93;
        }
        my $val = $xor ^ hex( "0x$inv_hexcode" );
        #
        # we convert the final value to a 4-digit hexadecimal
        #
        $enc_password .= sprintf( "%04x", $val );
    }
    return $enc_password;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;

    return $self->{name};
}

#---------------#
sub description {
#---------------#
    my ( $self ) = @_;

    return $self->{description};
}

#------#
sub id {
#------#
    my ( $self ) = @_;

    return $self->{id};
}

#------------#
sub password {
#------------#
    my ( $self ) = @_;

    return $self->{password};
}

#---------#
sub mdate {
#---------#
    my ( $self ) = @_;

    return $self->{mdate};
}

#----------#
sub locked {
#----------#
    my ( $self ) = @_;

    return $self->{locked};
}

#-----------#
sub TO_JSON {
#-----------#
    my ( $self ) = @_;


    return {
      0  => $self->{id},
      1  => $self->{name},
      2  => $self->{description} || '',
      3  => ( $self->{suspended} ) ? ( $self->{suspend_start} || '' ) : '',
      4  => ( $self->{locked} ) ? 'YES' : 'NO',
      5  => $self->{mdate},
      6  => $self->{password},
      DT_RowId => $self->{id} . '|' . $self->{password}
    };
}

1;
