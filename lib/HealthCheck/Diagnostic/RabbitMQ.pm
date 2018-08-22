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

    # The method the object needs to have for us to proceed
    my $method = 'get_server_properties';

    # These are the params that we actually use to make our decisions
    # and that we're going to return in the result to make that clear.
    my %decision_params = ( rabbit_mq => undef );

    # If we have a queue to check, that changes our requirements
    if ( defined $params{queue}
        or ( ref $self and defined $self->{queue} ) )
    {
        $method = 'queue_declare';
        $decision_params{$_} = undef for qw(
            queue
            channel
        );
    }

    # Now we prefer the params passed to check,
    # and fall back to what is on the instance.
    foreach my $param ( keys %decision_params ) {
        $decision_params{$param} = $params{$param};
        $decision_params{$param} ||= $self->{$param} if ref $self;
    }

    # The rabbit_mq param was only "known" so we could choose between
    # one that was passed to check and the one on the instance.
    my $rabbit_mq = delete $decision_params{rabbit_mq};
    $rabbit_mq = $rabbit_mq->(%params) if ref $rabbit_mq eq 'CODE';

    croak("'rabbit_mq' must have '$method' method") unless $rabbit_mq and do {
        local $@; eval { local $SIG{__DIE__}; $rabbit_mq->can($method) } };

    # In theory we could default to random channel in the
    # range of 1..$rabbit_mq->get_max_channel
    # but then we would have to:
    # 1. Hope it's not in use
    # 2. Open and then close it.
    # Instead we default to 1 as that's what our internal code does.
    $decision_params{channel} //= 1
        if exists $decision_params{channel};

    my $res = $self->SUPER::check(
        %params,
        %decision_params,
        rabbit_mq => $rabbit_mq,
    );

    # Make sure we report what we actually *used*
    # not what our parent may have copied out of %{ $self }
    $res->{data} = { %{ $res->{data} || {} }, %decision_params }
        if %decision_params;
    delete $res->{rabbit_mq};    # don't include the object in the result

    return $res;
}

sub run {
    my ( $self, %params ) = @_;
    my $rabbit_mq = $params{rabbit_mq};

    my $cb = sub { $rabbit_mq->get_server_properties };

    if ( defined $params{queue} ) {
        my $queue   = $params{queue};
        my $channel = $params{channel};

        $cb = sub {
            my $name = $rabbit_mq->queue_declare( $channel, $queue,
                { passive => 1 } );

            return { name => $name };
        };
    }

    my $data;
    {
        local $@;
        $data = eval { local $SIG{__DIE__}; $cb->() };

        if ( my $e = $@ ) {
            my $file = quotemeta __FILE__;
            $e =~ s/ at $file line \d+\.?\n\Z//ms;
            $e =~ s/^Declaring queue: //;
            return { status => 'CRITICAL', info => $e };
        }
    }

    return { status => 'OK', data => $data };
}

1;
__END__

=head1 SYNOPSIS

Check that you can talk to the server.

    my $health_check = HealthCheck->new( checks => [
        HealthCheck::Diagnostic::RabbitMQ->new( rabbit_mq => \&connect_mq ),
    ] );

Or verify that a queue exists,
has an appropriate number of listeners,
and not too many queued messages waiting.

    my $check_rabbit_mq => HealthCheck::Diagnostic::RabbitMQ->new(
        rabbit_mq => \&connect_mq,
        queue     => $queue_name,
        channel   => $channel,       # default channel is 1
    );

    my $health_check = HealthCheck->new( checks => [$check_rabbit_mq] );

Here the C<connect_mq> function could be something like:

    sub connect_mq {
        my $mq = Net::AMQP::RabbitMQ->new;
        $mq->connect( $host, {
            user            => $username,
            password        => $password,
            vhost           => $vhost,
        } );
        $mq->channel_open(1);
        return $mq;
    };

The C<< $mq->channel_open >> is only needed to check a queue,
in which case you will need to open the L</channel> that will be used.

Checking additional queues could be as easy as:

    $health_check->register( {
        label    => "other_rabbit_mq_check",
        invocant => $check_rabbit_mq,
        check    => sub { shift->check( @_, queue => 'other.queue' },
    } );


=head1 DESCRIPTION

Determines if the RabbitMQ connection is available.
Sets the C<status> to "OK" or "CRITICAL" based on the
return value from C<< rabbit_mq->get_server_properties >>.

If you pass in a L</queue>,
it will instead check that the queue exists.

=head1 ATTRIBUTES

Can be passed either to C<new> or C<check>.

=head2 rabbit_mq

A coderef that returns a
L<Net::AMQP::RabbitMQ> or L<Net::RabbitMQ> or compatible object,
or the object itself.

=head2 queue

The name of the queue to check whether it exists.

Accomplishes the check by using C<< rabbit_mq->queue_declare >>
to try to declare a passive queue.
Requires a L</channel>.

=head2 channel

Allow specifying which channel will be used to check the L</queue>.

The passed in L</rabbit_mq> must open this channel with C<channel_open>
to use this method.

Defaults to 1.

=head1 BUGS AND LIMITATIONS

L<Net::RabbitMQ> does not support C<get_server_properties> and so doesn't
provide a way to just check that the server is responding to
requests.

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>

=head1 CONFIGURATION AND ENVIRONMENT

None
