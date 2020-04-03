# NAME

HealthCheck::Diagnostic::RabbitMQ - Check connectivity and queues on a RabbitMQ server

# VERSION

version v1.1.4

# SYNOPSIS

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

        # All the rest are optional and only work on queue.
        listeners_min_critical => 0,
        listeners_min_warning  => 1,
        listeners_max_critical => 3,
        listeners_max_warning  => 3,    # noop, matches critical

        messages_critical => 10_000,
        messages_warning  => 1_000,
    );

    my $health_check = HealthCheck->new( checks => [$check_rabbit_mq] );

Here the `connect_mq` function could be something like:

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

The `$mq->channel_open` is only needed to check a queue,
in which case you will need to open the ["channel"](#channel) that will be used.

Checking additional queues could be as easy as:

    $health_check->register( {
        label    => "other_rabbit_mq_check",
        invocant => $check_rabbit_mq,
        check    => sub { shift->check( @_, queue => 'other.queue' },
    } );

# DESCRIPTION

Determines if the RabbitMQ connection is available.
Sets the `status` to "OK" or "CRITICAL" based on the
return value from `rabbit_mq->get_server_properties`.

If you pass in a ["queue"](#queue),
it will instead check that the queue exists
and if you additionally provide ["listeners"](#listeners) or ["messages"](#messages)
will also verify those limits.
Limits are ignored without a queue.

# ATTRIBUTES

Can be passed either to `new` or `check`.

## rabbit\_mq

A coderef that returns a
[Net::AMQP::RabbitMQ](https://metacpan.org/pod/Net%3A%3AAMQP%3A%3ARabbitMQ) or [Net::RabbitMQ](https://metacpan.org/pod/Net%3A%3ARabbitMQ) or compatible object,
or the object itself.

## queue

The name of the queue to check whether it exists.

Accomplishes the check by using `rabbit_mq->queue_declare`
to try to declare a passive queue.
Requires a ["channel"](#channel).

## channel

Allow specifying which channel will be used to check the ["queue"](#queue).

The passed in ["rabbit\_mq"](#rabbit_mq) must open this channel with `channel_open`
to use this method.

Defaults to 1.

## Limits

### listeners

With these set, checks to see that the number of listeners on
the ["queue"](#queue) is within the exclusive range.

Checked in the order listed here:

- listeners\_min\_critical

    Check is `CRITICAL` if the number of listeners is this many or less.

- listeners\_max\_critical

    Check is `CRITICAL` if the number of listeners is this many or more.

- listeners\_min\_warning

    Check is `WARNING` if the number of listeners is this many or less.

- listeners\_max\_warning

    Check is `WARNING` if the number of listeners is this many or more.

### messages

Thresholds for number of messages in the queue.

- messages\_critical

    Check is `CRITICAL` if the number of messages is this many or more.

- messages\_warning

    Check is `WARNING` if the number of messages is this many or more.

# BUGS AND LIMITATIONS

[Net::RabbitMQ](https://metacpan.org/pod/Net%3A%3ARabbitMQ) does not support `get_server_properties` and so doesn't
provide a way to just check that the server is responding to
requests.

# DEPENDENCIES

[HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic)

# CONFIGURATION AND ENVIRONMENT

None

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 - 2020 by Grant Street Group.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
