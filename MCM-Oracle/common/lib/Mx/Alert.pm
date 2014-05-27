package Mx::Alert;
 
use strict;
use warnings;

use Mx::Config;
use Mx::Log;
use Mx::Murex;
use Mx::Mail;
use Mx::DBaudit;
use IO::File;
use Carp;
 
#
# Atttributes:
#
# $name
# $item
# $category
# $ack_needed
# $disable_flag
# $retrigger_count
# $retrigger_time
# $message_template
# $message
# $warning_threshold
# $warning_actions
# $warning_address
# $fail_threshold
# $fail_actions
# $fail_address
# $business_date
#

use constant ACTION_MAIL     => 1;
use constant ACTION_INCIDENT => 2;

our $LEVEL_WARNING = 'warning';
our $LEVEL_FAIL    = 'failure';
 
#-------#
sub new {
#-------#
    my ( $class, %args ) = @_;
 
 
    my $logger = $args{logger} or croak 'no logger defined.';
    my $self = {};
    $self->{logger} = $logger;
    
    my $config;
    unless ( $config = $args{config} ) { 
        $logger->logdie("missing argument in initialisation of alert object (config)");
    }
    $self->{config} = $config;

    my $alert_configfile = $config->retrieve('ALERT_CONFIGFILE');
    my $alert_config     = Mx::Config->new( $alert_configfile );
 
    my $name;
    unless ( $name = $args{name} ) { 
        $logger->logdie("missing argument in initialisation of alert object (name)");
    }
    $self->{name} = $name;

    my $alert_ref = $alert_config->retrieve("ALERTS.$name");

    $self->{category}          = $alert_ref->{category};
    $self->{message_template}  = $alert_ref->{message};

    $self->{warning_threshold} = $alert_ref->{warning_threshold};
    $self->{fail_threshold}    = $alert_ref->{fail_threshold};

    $self->{warning_address}   = $alert_ref->{warning_address};
    $self->{fail_address}      = $alert_ref->{fail_address};

    if ( $alert_ref->{warning_action} =~ /\bmail\b/ ) {
        push @{$self->{warning_actions}}, ACTION_MAIL;
    }

    if ( $alert_ref->{warning_action} =~ /\bincident\b/ ) {
        push @{$self->{warning_actions}}, ACTION_INCIDENT;
    }

    if ( $alert_ref->{fail_action} =~ /\bmail\b/ ) {
        push @{$self->{fail_actions}}, ACTION_MAIL;
    }

    if ( $alert_ref->{fail_action} =~ /\bincident\b/ ) {
        push @{$self->{fail_actions}}, ACTION_INCIDENT;
    }

    $self->{ack_needed}          = ( $alert_ref->{acknowledgement} =~ /yes/ ) ? 1 : 0;
    $self->{retrigger_count}     = $alert_ref->{retrigger_count} || 0;
    $self->{retrigger_time}      = $alert_ref->{retrigger_time}  || 0;
    $self->{disable_flag}        = $alert_ref->{disable_flag};
    $self->{global_disable_flag} = $alert_config->global_disable_flag;

    $self->{business_date} = Mx::Murex->businessdate( logger => $logger, config => $config );

    $self->{db_audit} = undef;

    bless $self, $class;
    return $self;
}

#
# item
# values
#
#---------#
sub check {
#---------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};

    my @values;
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $logger->logdie("values must be an array reference");
        }
        @values = @{$args{values}};
    }
    else {
        $logger->logdie("alert check: no values supplied");
    }

    my $item = $args{item} || '';

    my $check_value       = $values[0];
    my $warning_threshold = $self->{warning_threshold};
    my $fail_threshold    = $self->{fail_threshold};

    if ( $check_value < $warning_threshold ) {
        return 1;
    }
    elsif ( $check_value < $fail_threshold ) {
        $self->trigger( item => $item, values => [ @values ], level => $LEVEL_WARNING );
    }
    else {
        $self->trigger( item => $item, values => [ @values ], level => $LEVEL_FAIL );
    }
}

#
# item
# values
# level
#
#-----------#
sub trigger {
#-----------#
    my ( $self, %args ) = @_;


    my $logger    = $self->{logger};
    my $name      = $self->{name};
    my $item      = $args{item} || '';
    my $timestamp = time();

    my $level;
    unless ( $level = $args{level} ) {
        $logger->logdie("alert trigger ($name): no level specified");
    }

    unless ( $level eq $LEVEL_WARNING or $level eq $LEVEL_FAIL ) {
        $logger->logdie("alert trigger ($name): wrong level specified ($level)");
    }

    $logger->debug("received trigger for alert $name (level: $level item: $item)");

    return 1 unless $self->check_disable();

    my @values;
    if ( $args{values} ) {
        unless ( ref( $args{values} ) eq 'ARRAY' ) {
            $logger->logdie("values must be an array reference");
        }
        @values = @{$args{values}};
    }
    else {
        $logger->logdie("alert check: no values supplied");
    }

    $self->_prepare_message( values => [ @values ], item => $item );

    return 1 unless $self->check_trigger( item => $item, level => $level );

    my $id = $self->_store( item => $item, level => $level, timestamp => $timestamp );

    return $id unless $self->check_global_disable();

    my $actions_ref = ( $level eq $LEVEL_WARNING ) ? $self->{warning_actions} : $self->{fail_actions};

    foreach my $action ( @{$actions_ref} ) {
        if ( $action == ACTION_MAIL ) {
            $self->_send_mail( item => $item, level => $level, timestamp => $timestamp );
        }
        elsif ( $action == ACTION_INCIDENT ) {
            $self->_create_incident( item => $item, level => $level, timestamp => $timestamp );
        }
    }

    return $id;
}

#---------------------#
sub acknowledge_alert {
#---------------------#
    my ( $class, %args ) = @_;

    
    my $id       = $args{id};
    my $user     = $args{user};
    my $db_audit = $args{db_audit};

    $db_audit->ack_alert( id => $id, user => $user );
}

#-----------------#
sub check_trigger {
#-----------------#
    my ( $self, %args ) = @_;


    return 1 unless $self->{ack_needed};

    my $logger = $self->{logger};
    my $config = $self->{config};

    $self->{db_audit}   = $self->{db_audit} || Mx::DBaudit->new( logger => $logger, config => $config );
    my $name            = $self->{name};
    my $business_date   = $self->{business_date};
    my $retrigger_count = $self->{retrigger_count};
    my $retrigger_time  = $self->{retrigger_time};
    my $level           = $args{level};
    my $item            = $args{item};

    my $result = $self->{db_audit}->retrieve_last_alert( name => $name, item => $item, level => $level, business_date => $business_date );

    return 1 unless @{$result};

    my ($id, $timestamp, $ack_received, $trigger_count) = @{$result};

    if( $ack_received ) {
        $logger->debug("alert $name (level: $level item: $item) is already acknowledged, trigger allowed");
        return 1;
    }
    elsif ( $trigger_count >= $retrigger_count && $retrigger_count != 0 ) {
        $logger->debug("alert $name (level: $level item: $item) has exceeded maximum trigger count ($trigger_count), trigger allowed");
        return 1;
    }
    elsif ( ( time() - $timestamp ) >= $retrigger_time && $retrigger_time != 0 ) {
        my $delta = time() - $timestamp;
        $logger->debug("alert $name (level: $level item: $item) has exceeded maximum trigger time ($delta), trigger allowed");
        return 1;
    }
    else {
        $logger->debug("alert $name (level: $level item: $item) is not yet acknowledged, no trigger allowed");
        $self->{db_audit}->trigger_alert( id => $id, message => $self->{message} );
        $self->{db_audit}->close();
        $self->{db_audit} = undef;
        return 0;
    }
}

#-----------------#
sub check_disable {
#-----------------#
    my ( $self ) = @_;


    my $logger       = $self->{logger};
    my $name         = $self->{name};
    my $disable_flag = $self->{disable_flag};

    if ( -f $disable_flag ) {
        $logger->debug("alert $name is disabled, no trigger allowed");
        return 0;
    }
    else {
        return 1;
    }
}

#------------------------#
sub check_global_disable {
#------------------------#
    my ( $self ) = @_;


    my $logger              = $self->{logger};
    my $global_disable_flag = $self->{global_disable_flag};

    if ( -f $global_disable_flag ) {
        $logger->debug("alerts are globally disabled");
        return 0;
    }
    else {
        return 1;
    }
}

#-----------#
sub disable {
#-----------#
    my ( $self ) = @_;


    my $logger       = $self->{logger};
    my $name         = $self->{name};
    my $disable_flag = $self->{disable_flag};

    unless ( open FH, ">$disable_flag" ) {
        $logger->error("alert $name: cannot create disable flag $disable_flag: $!");
        return 0;
    }
    close(FH);

    $logger->info("alert $name is disabled through disable flag $disable_flag");

    return 1;
}

#----------#
sub enable {
#----------#
    my ( $self ) = @_;


    my $logger       = $self->{logger};
    my $name         = $self->{name};
    my $disable_flag = $self->{disable_flag};

    unless ( unlink $disable_flag ) {
        $logger->error("alert $name: cannot remove disable flag $disable_flag: $!");
        return 0;
    }

    $logger->info("alert $name is re-enabled");

    return 1;
}

#-----------------------#
sub set_warning_address {
#-----------------------#
    my ( $self, $address ) = @_;


    $self->{warning_address} = $address;
}

#--------------------#
sub set_fail_address {
#--------------------#
    my ( $self, $address ) = @_;


    $self->{fail_address} = $address;
}

#--------#
sub name {
#--------#
    my ( $self ) = @_;


    return $self->{name};
}

#--------------------#
sub _prepare_message {
#--------------------#
    my ( $self, %args ) = @_;


    my @values = @{$args{values}};
    my $item   = $args{item};

    my $message_template = $self->{message_template};

    $message_template =~ s/__ITEM__/$item/g;

    my @values_to_use = ();
    my $nr_placeholders = ( $message_template =~ tr/%/%/ );
    $nr_placeholders--;
    @values_to_use = @values[0..$nr_placeholders] if $nr_placeholders >= 0;

    $self->{message} = sprintf $message_template, @values_to_use;
}

#----------#
sub _store {
#----------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    my $item         = $args{item};
    my $level        = $args{level};
    my $timestamp    = $args{timestamp};
    my $ack_received = ( $self->{ack_needed} ) ? 0 : 1;
    my $logfile      = $logger->filename;

    $self->{db_audit} = $self->{db_audit} || Mx::DBaudit->new( logger => $logger, config => $config );
    
    my $id = $self->{db_audit}->record_alert( name => $self->{name}, item => $item, category => $self->{category}, level => $level, message => $self->{message}, timestamp => $timestamp, business_date => $self->{business_date}, ack_received => $ack_received, logfile => $logfile );

    $self->{db_audit}->close();
    $self->{db_audit} = undef;

    return $id;
}

#--------------#
sub _send_mail {
#--------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    $logger->debug("sending mail");

    my $env       = $config->MXENV;
    my $level     = ( $args{level} eq $LEVEL_WARNING ) ? 'WARNING' : 'FAILURE';
    my $address   = ( $args{level} eq $LEVEL_WARNING ) ? $self->{warning_address} : $self->{fail_address};
    my $name      = $self->{name};
    my $category  = $self->{category};
    my $message   = $self->{message};
    my $item      = $args{item};
    my $date      = localtime( $args{timestamp} );

    my $subject = sprintf "%s - %s - %s", $env, $level, $name;
    $subject .= " - $item" if $item;

    my $body = <<EOT;
Date:    $date
Item:    $item
Message: $message
EOT

    my $mail = Mx::Mail->new( to => $address, subject => $subject, body => $body, logger => $logger, config => $config );

    $mail->send();
}

#--------------------#
sub _create_incident {
#--------------------#
    my ( $self, %args ) = @_;


    my $logger = $self->{logger};
    my $config = $self->{config};

    $logger->debug("creating incident");

    my $logdir = Mx::Log->create_logdir( directory => $config->LOGDIR );
    my $logfile = $logdir . '/alerts.log';

    my $timestamp = localtime( $args{timestamp} );
    my $level     = ( $args{level} eq $LEVEL_WARNING ) ? 'warning' : 'failure';

    my $fh;
    unless ( $fh = IO::File->new( ">> $logfile" ) ) {
         $logger->error("cannot open $logfile: $!");
         return;
    }

    printf  $fh "%s;%s;%s;%s;%s;%s\n", $timestamp, $config->MXENV, $level, $self->{name}, $args{item}, $self->{message};

    $fh->close();
}
