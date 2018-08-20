use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic::RabbitMQ;

my $nl = $] >= 5.016 ? ".\n" : "\n";

my $must_have = "'rabbit_mq' must have 'get_server_properties' method"
    . " at %s line %d$nl";

eval { HealthCheck::Diagnostic::RabbitMQ->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 );

eval { HealthCheck::Diagnostic::RabbitMQ->new->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 );

eval { HealthCheck::Diagnostic::RabbitMQ->new( rabbit_mq => {} )->check };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 );

eval { HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => bless {} ) };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 );

eval { HealthCheck::Diagnostic::RabbitMQ->check( rabbit_mq => sub {} ) };
is $@, sprintf( $must_have, __FILE__, __LINE__ - 1 );

done_testing;

