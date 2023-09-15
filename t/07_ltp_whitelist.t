use Mojo::Base -strict;

use Mojo::File;
use Mojo::JSON;
use Test::More;
use Test::MockModule;
use Test::Warnings;
use Test::MockObject;
use LTP::WhiteList;
use testapi;


subtest 'whitelist_entry_match' => sub {

    my $entry = {
        product => '^sle:15-SP[23]$'
    };
    my $env = {
        foo => 'something',
        product => 'sle:15-SP3'
    };

    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Product match regex");

    $entry->{arch} = '^x86_64$';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), undef, "Missing field in ltp-environment, doesn't match the entry");

    $env->{arch} = 'foo';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), undef, "Different value in ltp-environment, doesn't match the entry");

    $env->{arch} = 'x86_64';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Multiple values need match");

    $env->{flavor} = 'EC2-HVM';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Entry match with less attributes");

    for my $attr (qw(product ltp_version revision arch kernel backend retval flavor)) {
        $entry = {$attr => '^incredible_value$'};
        $env = {$attr => "incredible_value"};
        is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Check match attribute $attr");
    }

};


subtest override_known_failures => sub {
    set_var('LTP_KNOWN_ISSUES_LOCAL' => 'test_known_issues.json');
    my $self = Test::MockObject->new();
    my $msg;
    $self->mock('record_soft_failure_result' => sub { shift; $msg = shift });
    $self->{result} = 'not_set';

    my $known_issues_json = {
        testsuite_01 => {
            test_01 => [
                {
                    product => '^sle:15',
                    retval => '^2$',
                    message => 'overwrite result 2'
                },
                {
                    product => '^sle:12',
                    message => 'overwrite for product sle:12',
                    skip => 1
                },
                {
                    product => '^sle:11',
                    message => 'overwrite ZERO result',
                    retval => '^0$'
                },
                {
                    product => '^sle:11',
                    message => 'overwrite TWO result',
                    retval => '^2$'
                }
            ],
        }
    };

    Mojo::File::path('test_known_issues.json')->spew(Mojo::JSON::encode_json($known_issues_json));

    my $env = {product => 'sle:15', retval => 0};
    my $whitelist = LTP::WhiteList->new();
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 0, "Check override_known_failures doesn't override");

    $env = {product => 'sle:15', retval => 2};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures single retval");

    $env = {product => 'sle:15', retval => [0, 2]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures retval array");

    $env = {product => 'sle:15', retval => [0, 2, 3]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 0, "Check override_known_failures don't override on new error");


    $env = {product => 'sle:12', retval => 0};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override with retval=0");

    $env = {product => 'sle:12', retval => [0]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override with retval=0");

    $env = {product => 'sle:12', retval => 1};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override");

    $env = {product => 'sle:12', retval => [1]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override");


    $msg = undef;
    $env = {product => 'sle:11', retval => 0};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check for zero result");
    like($msg, qr/ZERO/, 'Check softrecord_message contains correct entry message ZERO');

    $msg = undef;
    $env = {product => 'sle:11', retval => [0, 0, 0]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Check for zero result, if all are zero");
    like($msg, qr/ZERO/, 'Check softrecord_message contains correct entry message ZERO');

    delete $self->{result};
    $msg = undef;
    $env = {product => 'sle:11', retval => [0, 0, 2, 0]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 1, "Ignore zero and softfail");
    like($msg, qr/TWO/, 'Check softrecord_message contains correct entry message TWO');
    is($self->{result}, 'softfail', 'Result was patched to `softfail`');

    $env = {product => 'sle:11', retval => [0, 0, 1, 0]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 0, "Ignore zero and fail");

    $env = {product => 'sle:11', retval => [0, 2, 1, 0]};
    is($whitelist->override_known_failures($self, $env, 'testsuite_01', 'test_01'), 0, "Ignore zero and fail [2]");

};

done_testing;
