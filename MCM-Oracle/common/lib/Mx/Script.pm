package Mx::Script;

use strict;

use Mx::GenericScript;

our @ISA = qw(Mx::GenericScript);

*errstr = *Mx::GenericScript::errstr;

#-------#
sub new {
#-------#
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args, type => Mx::GenericScript::SCRIPT);
    return $self;
}

1;
