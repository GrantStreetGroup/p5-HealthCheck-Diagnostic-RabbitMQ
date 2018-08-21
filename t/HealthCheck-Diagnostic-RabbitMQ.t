use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic::RabbitMQ;

my $nl = $] >= 5.016 ? ".\n" : "\n";

my $must_have = "'rabbit_mq' must have 'get_server_properties' method"
    . " at %s line %d$nl";

eval { HealthCheck::Diagnostic::RabbitMQ->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 ), "No params to class check";

eval { HealthCheck::Diagnostic::RabbitMQ->new->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 ), "No params to instance check";

eval { HealthCheck::Diagnostic::RabbitMQ->new( rabbit_mq => {} )->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 ), "rabbit_mq as hashref";

eval { HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => bless {} ) };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 ), "rabbit_mq as anonymous object";

eval { HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => sub {} ) };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 ), "rabbit_mq as empty coderef";


my $rabbit_mq = sub { return bless {}, 'My::RabbitMQ' };

{
    no warnings 'once';
    local *My::RabbitMQ::get_server_properties
        = sub { +{ fake => 'properties' } };
    use warnings 'once';

    is_deeply(
        HealthCheck::Diagnostic::RabbitMQ->new( rabbit_mq => $rabbit_mq )
            ->check,
        {   label    => 'rabbit_mq',
            'status' => 'OK',
            'data'   => { 'fake' => 'properties' }
        },
        "OK status as expected"
    );

    is_deeply(
        HealthCheck::Diagnostic::RabbitMQ->check(
            rabbit_mq => $rabbit_mq->()
        ),
        { 'status' => 'OK', 'data' => { 'fake' => 'properties' } },
        "OK status as expected with rabbit_mq object passed to check()"
    );
}

{
    no warnings 'once';
    local *My::RabbitMQ::get_server_properties = sub { Carp::croak('ded') };
    use warnings 'once';

    is_deeply(
        HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => $rabbit_mq ),
        { 'status' => 'CRITICAL', info => 'ded' },
        "CRITICAL status as expected"
    );
}

{
    no warnings 'once';
    local *My::RabbitMQ::get_server_properties = sub { Carp::confess('ded') };
    use warnings 'once';

    my $res
        = HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => $rabbit_mq );
    my $at = sprintf "at %s line .*"
        . "HealthCheck::Diagnostic::RabbitMQ::check\(.*\)"
        . " called at %s line %s.",
        __FILE__, __FILE__, __LINE__ - 5;

    my $info = delete $res->{info};
    like $info, qr/^ded $at$/ms, "Got full stack trace without trimming";

    is_deeply $res, { 'status' => 'CRITICAL' },
        "CRITICAL status with stack trace as expected";
}

done_testing;
