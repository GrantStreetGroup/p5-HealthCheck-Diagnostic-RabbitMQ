use GSG::Gitc::CPANfile $_environment;

requires 'HealthCheck::Diagnostic';

test_requires 'Test::Strict';

1;
on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG::Internal';
};
