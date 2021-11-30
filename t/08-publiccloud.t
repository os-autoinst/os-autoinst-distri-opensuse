use Mojo::Base -strict;
use Test::More;
use Test::Exception;
use Test::Warnings;
use publiccloud::gcp_client;
use publiccloud::provider;
use Data::Dumper;
use testapi;


subtest 'get_next_gcp_role' => sub {
    my $gcp = publiccloud::gcp_client->new();
    my $role = $gcp->get_next_vault_role();
    isnt($role, $gcp->get_next_vault_role(), "Two calls don't return the same role");

    set_var('PUBLIC_CLOUD_VAULT_ROLES', 'openqa_roleX');
    is($gcp->get_next_vault_role(), 'openqa_roleX', 'Only one role exists (1)');
    is($gcp->get_next_vault_role(), 'openqa_roleX', 'Only one role exists (2)');
};

subtest 'vault_retry' => sub {
    my $vault = publiccloud::vault->new();

    my $cnt = 0;
    my $max_failed = 1;
    my $test_func1 = sub {
        while ($cnt++ < $max_failed) {
            die "FOO FAA";
        }
        return 'SUCCESS';
    };

    $cnt = 0; $max_failed = 0;
    is($vault->retry($test_func1, max_tries => 0, sleep_duration => 0), 'SUCCESS', 'No exception with 1 retry');

    $cnt = 0; $max_failed = 2;
    is($vault->retry($test_func1, max_tries => 3, sleep_duration => 0), 'SUCCESS', 'No exception with 1 retry');

    $cnt = 0; $max_failed = 3;
    throws_ok { $vault->retry($test_func1, max_tries => 3, sleep_duration => 0) } qr/call failed after 3/, 'Exception if retry Exhausted';

    $cnt = 0; $max_failed = 3;
    set_var('PUBLIC_CLOUD_VAULT_TRIES', 4);
    is($vault->retry($test_func1, max_tries => 3, sleep_duration => 0), 'SUCCESS', 'OpenQA variable has precedence over arguments');
};

done_testing;
