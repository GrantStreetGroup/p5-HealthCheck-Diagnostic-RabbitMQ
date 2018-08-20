package HealthCheck::Diagnostic::RabbitMQ;

# ABSTRACT: Check connectivity and queues on a RabbitMQ server
# VERSION

use 5.010;
use strict;
use warnings;
use parent 'HealthCheck::Diagnostic';

use Carp;

sub new {
    my ($class, @params) = @_;

    # Allow either a hashref or even-sized list of params
    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    return $class->SUPER::new(
        label => 'rabbit_mq',
        %params
    );
}

sub check {
    my ( $self, %params ) = @_;

    my $rabbit_mq = $params{rabbit_mq};
    $rabbit_mq ||= $self->{rabbit_mq} if ref $self;
    $rabbit_mq = $rabbit_mq->(%params) if ref $rabbit_mq eq 'CODE';

    my $method = 'get_server_properties';

    croak("'rabbit_mq' must have '$method' method") unless $rabbit_mq and do {
        local $@; eval { local $SIG{__DIE__}; $rabbit_mq->can($method) } };

    my $res = $self->SUPER::check( %params, rabbit_mq => $rabbit_mq );
    delete $res->{rabbit_mq};    # don't include the object in the result

    return $res;
}

1;
__END__

=head1 SYNOPSIS

    my $health_check = HealthCheck->new( checks => [
        HealthCheck::Diagnostic::RabbitMQ->new( rabbit_mq => \&connect_mq ),
    ] );

=head1 DESCRIPTION

Determines if the RabbitMQ connection is available.
Sets the C<status> to "OK" or "CRITICAL" based on the
return value from C<< rabbit_mq->get_server_properties >>.

=head1 ATTRIBUTES

Can be passed either to C<new> or C<check>.

=head2 rabbit_mq

A coderef that returns a
L<Net::AMQP::RabbitMQ> or compatible object,
or the object itself.

=head2

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>

=head1 CONFIGURATION AND ENVIRONMENT

None
