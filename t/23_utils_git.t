use strict;
use warnings;
use testapi;
use Test::MockModule;
use Test::Exception;
use Test::More;

use Utils::Git;

subtest '[git_clone] Compose command' => sub {
    my $mock_git = Test::MockModule->new('Utils::Git', no_auto => 1);
    my @calls;
    $mock_git->redefine(assert_script_run => sub { @calls = $_[0]; return 0; });
    $mock_git->noop('upload_logs');
    $mock_git->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $repository = 'https://funhub.com/spicy_code/global_variablEs-on1y';

    git_clone($repository);
    is join(' ', @calls), "git clone $repository", "Check base command composition";

    git_clone($repository, skip_ssl_verification => 'true',
        output_log_file => 'output.log',
        branch => 'world_domination',
        single_branch => 'yes',
        depth => 'not_too_deep',
        target_dir => '/tmp/some_dir'
    );
    ok(grep(/git.*-c http.sslVerify=false.*clone/, @calls), 'Option "-c http.sslVerify=false " must be between "git" and "clone"');
    ok(grep(/clone.*--branch world_domination.*$repository/, @calls), 'Checkout branch - option must be between "clone" repository url');
    ok(grep(/clone.*--depth not_too_deep.*$repository/, @calls), 'Argument "--depth" for shallow clone - option must be between "clone" repository url');
    ok(grep(/clone.*--single-branch.*$repository/, @calls), 'Argument "--single-branch" for cloning a single branch only');
    ok(grep(/clone.*\/tmp\/some_dir/, @calls), 'Target directory being specified');
    ok(grep(/2>&1 | tee output.log$/, @calls), 'Log output to a file');
    ok(grep(/^set -o pipefail;/, @calls), 'Set bash command to fail immediately with logging');
};

subtest '[git_clone] Test exceptions' => sub {
    my $mock_git = Test::MockModule->new('Utils::Git', no_auto => 1);
    $mock_git->redefine(assert_script_run => sub { return 0; });
    $mock_git->noop(qw(record_info upload_logs));

    dies_ok { git_clone() } 'Croak with missing repository argument';
};

done_testing;
