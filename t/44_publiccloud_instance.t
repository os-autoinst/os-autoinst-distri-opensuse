# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::instance -- ssh command construction
# and the thin provider-delegating methods
# (start/stop/get_state/wait_for_state).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
# Deterministic fake clock: sleep() advances mocked time() instead of spending
# real wall-clock seconds, so the retry_ssh_command and wait_for_state polling
# loops run fast. Must be loaded before the module under test is compiled.
use Test::Mock::Time;

use testapi 'set_var';

use publiccloud::instance;

# ---------------------------------------------------------------------------
# _prepare_ssh_cmd / ssh_script_run command construction
# ---------------------------------------------------------------------------
subtest '[_prepare_ssh_cmd] composes ssh command' => sub {
    my $inst = publiccloud::instance->new(
        public_ip => '203.0.113.5',
        username => 'cloudadmin',
        ssh_opts => '-o StrictHostKeyChecking=no',
    );
    my $cmd = $inst->_prepare_ssh_cmd(cmd => 'uname -a');
    like($cmd, qr/\bssh\b/, 'starts an ssh invocation');
    like($cmd, qr/cloudadmin\@203\.0\.113\.5/, 'uses username@public_ip');
    like($cmd, qr/StrictHostKeyChecking=no/, 'includes ssh_opts');
    like($cmd, qr/-E \/var\/tmp\/ssh_sut\.log/, 'adds -E log when not already present');
    like($cmd, qr/uname -a/, 'embeds the remote command');
};

subtest '[_prepare_ssh_cmd] dies without cmd' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    throws_ok { $inst->_prepare_ssh_cmd() } qr/No command defined/, 'missing cmd dies';
};

subtest '[_wrap_timeout] wraps with timeout when apply_graceful_timeout' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

    my %args = (timeout => 100, apply_graceful_timeout => 1);
    my $ssh_cmd = 'ssh foo';
    $inst->_wrap_timeout(\%args, \$ssh_cmd);
    like($ssh_cmd, qr/^timeout --foreground -k 10s 100 ssh foo$/, 'wrapped in timeout call');
    is($args{timeout}, 120, 'script_run timeout bumped by 20s buffer');
    ok(!exists $args{apply_graceful_timeout}, 'apply_graceful_timeout consumed');

    # Without the flag: no wrapping
    my %args2 = (timeout => 50);
    my $ssh_cmd2 = 'ssh bar';
    $inst->_wrap_timeout(\%args2, \$ssh_cmd2);
    is($ssh_cmd2, 'ssh bar', 'command untouched when flag not set');
    is($args2{timeout}, 50, 'timeout unchanged when flag not set');
};

subtest '[ssh_script_run] delegates to script_run with built cmd' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my ($seen_cmd, %seen_args);
    $instance->redefine(script_run => sub { my ($c, %a) = @_; $seen_cmd = $c; %seen_args = %a; return 0 });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.9', username => 'bob', ssh_opts => '-q');
    my $rc = $inst->ssh_script_run(cmd => 'echo hi', timeout => 42);
    is($rc, 0, 'returns script_run rc');
    like($seen_cmd, qr/bob\@10\.0\.0\.9/, 'ssh cmd targets the instance');
    like($seen_cmd, qr/echo hi/, 'embeds command');
    is($seen_args{timeout}, 42, 'timeout forwarded');
    is($seen_args{quiet}, 1, 'quiet defaults to 1');
    ok(!exists $seen_args{cmd}, 'cmd stripped before script_run');
    ok(!exists $seen_args{ssh_opts}, 'ssh_opts stripped before script_run');
};

subtest '[ssh_script_output] strips trailing connection-closed line' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instance->redefine(script_output => sub { "real output\nConnection to 10.0.0.9 closed." });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.9', username => 'bob');
    my $out = $inst->ssh_script_output(cmd => 'cat file');
    like($out, qr/real output/, 'keeps real output');
    unlike($out, qr/Connection to .* closed/, 'strips connection-closed trailer');
};

subtest '[scp] composes scp command and rewrites only remote: paths' => sub {
    # remote: is rewritten to the instance identity (user@public_ip:), while
    # local paths and an explicit user@host are passed through verbatim. -E is
    # stripped from ssh_opts because scp does not accept it.
    my @cases = (
        {
            name => 'rewrites remote: in source (download)',
            username => 'DONALDUCK',
            ssh_opts => '-o X=y -E /tmp/log',
            src => 'remote:/var/log/messages',
            dst => '/tmp/messages',
            like => [qr/^scp /, qr/DONALDUCK\@198\.51\.100\.2:\/var\/log\/messages/, qr/"\/tmp\/messages"/],
            unlike => [qr/DONALDUCK\@198\.51\.100\.2:\/tmp\/messages/, qr/-E /],
        },
        {
            name => 'rewrites remote: in destination (upload)',
            username => 'GOOFY',
            src => '/tmp/foo',
            dst => 'remote:/home/admin/foo',
            like => [qr/GOOFY\@198\.51\.100\.2:\/home\/admin\/foo/, qr/"\/tmp\/foo"/],
            unlike => [qr/GOOFY\@198\.51\.100\.2:\/tmp\/foo/],
        },
        {
            name => 'neither path has remote:',
            username => 'admin',
            src => '/tmp/src',
            dst => '/tmp/dst',
            like => [qr/"\/tmp\/src"/, qr/"\/tmp\/dst"/],
            unlike => [qr/admin\@198\.51\.100\.2/],
        },
        {
            name => 'explicit user@host:/path in source',
            username => 'admin',
            src => 'other@example.com:/etc/hosts',
            dst => '/tmp/hosts',
            like => [qr/"other\@example\.com:\/etc\/hosts"/],
            unlike => [qr/admin\@198\.51\.100\.2/],
        },
    );

    foreach my $case (@cases) {
        my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
        my @calls;
        $instance->redefine(assert_script_run => sub { push @calls, $_[0]; return 0 });
        $instance->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
        my $inst = publiccloud::instance->new(public_ip => '198.51.100.2', username => $case->{username}, ssh_opts => $case->{ssh_opts} // '');

        $inst->scp($case->{src}, $case->{dst});

        note("\n  -->  " . join("\n  -->  ", @calls));
        like($calls[0], $_, "$case->{name}: matches $_") for @{$case->{like}};
        unlike($calls[0], $_, "$case->{name}: does not match $_") for @{$case->{unlike} // []};
    }
};

subtest '[scp] timeout defaults to SSH_TIMEOUT and is overridable' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my %seen;
    $instance->redefine(assert_script_run => sub { my ($c, %a) = @_; %seen = %a; return 0 });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

    $inst->scp('/tmp/a', '/tmp/b');
    is($seen{timeout}, 90, 'defaults to SSH_TIMEOUT (90s) when not given');

    $inst->scp('/tmp/a', '/tmp/b', timeout => 300);
    is($seen{timeout}, 300, 'custom timeout forwarded to assert_script_run');
};

subtest '[scp] proceed_on_failure controls failure handling' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my $assert_called;
    $instance->redefine(assert_script_run => sub { $assert_called++; return 0 });
    my $script_run_ret;
    $instance->redefine(script_run => sub { return $script_run_ret });
    $instance->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

    # proceed_on_failure=1 and scp fails: no die, no assert_script_run, an info is recorded
    $script_run_ret = 1;
    $assert_called = 0;
    lives_ok { $inst->scp('/tmp/a', '/tmp/b', proceed_on_failure => 1) }
    'does not die on scp failure when proceed_on_failure is set';
    is($assert_called, 0, 'assert_script_run not used when proceed_on_failure is set');

    # proceed_on_failure=1 and scp succeeds
    $script_run_ret = 0;
    $inst->scp('/tmp/a', '/tmp/b', proceed_on_failure => 1);
    is($assert_called, 0, 'assert_script_run not used when proceed_on_failure is set');

    # default (proceed_on_failure not set): the copy is asserted
    $assert_called = 0;
    $inst->scp('/tmp/a', '/tmp/b');
    is($assert_called, 1, 'assert_script_run used by default');
};

subtest '[retry_ssh_command] retries then succeeds' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @rcs = (1, 1, 0);
    my $calls = 0;
    $instmod->redefine(ssh_script_run => sub { $calls++; return shift @rcs });
    my $rc = $inst->retry_ssh_command(cmd => 'true', retry => 5, delay => 0);
    is($rc, 0, 'returns 0 on eventual success');
    is($calls, 3, 'stopped retrying after first success');
};

subtest '[retry_ssh_command] dies after exhausting retries' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instmod->redefine(ssh_script_run => sub { 1 });
    throws_ok { $inst->retry_ssh_command(cmd => 'false', retry => 2, delay => 0) }
    qr/Waiting for Godot: false/, 'dies with command in message';
};

# ---------------------------------------------------------------------------
# Provider-delegating methods
# ---------------------------------------------------------------------------
subtest '[stop/start/get_state] delegate to provider' => sub {
    my %provider_calls;
    my $provider = Test::MockObject->new;
    $provider->mock(stop_instance => sub { $provider_calls{stop}++; return });
    $provider->mock(start_instance => sub { $provider_calls{start}++; return });
    $provider->mock(get_state_from_instance => sub { $provider_calls{state}++; return 'running' });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    $inst->stop();
    is($provider_calls{stop}, 1, 'stop delegates to provider->stop_instance');

    is($inst->get_state(), 'running', 'get_state returns provider state');
    is($provider_calls{state}, 1, 'get_state delegates to provider');
};

subtest '[wait_for_state] returns when state matches' => sub {
    my @states = ('pending', 'pending', 'running');
    my $provider = Test::MockObject->new;
    $provider->mock(get_state_from_instance => sub { shift @states });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    lives_ok { $inst->wait_for_state('running', 100) } 'returns once desired state reached';
};

subtest '[wait_for_state] dies on timeout' => sub {
    my $provider = Test::MockObject->new;
    $provider->mock(get_state_from_instance => sub { 'pending' });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    # A zero timeout makes the deadline already in the past on the first check,
    # so the method gives up immediately and dies. The die message interpolates
    # an as-yet-undef $current, so silence that expected warning.
    local $SIG{__WARN__} = sub { };
    throws_ok { $inst->wait_for_state('running', 0) }
    qr/instance state is not 'running'/, 'dies when state never matches before timeout';
};

subtest '[wait_for_ssh_unreachable]' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @calls;
    $instmod->redefine(script_retry => sub { push @calls, $_[0]; return 0; });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $provider = Test::MockObject->new;
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    $inst->wait_for_ssh_unreachable();

    note("\n  -->  " . join("\n  -->  ", @calls));
    like($calls[0], qr/nc.*10\.0\.0\.1.*22/, 'nc command composed with the instance public ip');
};

subtest '[wait_for_ssh_login]' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @calls;
    my @call_args;
    $instmod->redefine(ssh_script_retry => sub {
            my $self = shift;
            my $cmd = shift;
            my (%args) = @_;
            push @calls, $cmd;
            push @call_args, \%args;
            return 0; });
    my $provider = Test::MockObject->new;
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    $inst->wait_for_ssh_login();

    is(scalar @calls, 1, 'ssh_script_retry called exactly once');
    is($calls[0], 'true', 'runs the "true" command to verify login');
    like($call_args[0]->{ssh_opts}, qr/ControlPath=none/, 'ssh_opts includes ControlPath=none');
    like($call_args[0]->{ssh_opts}, qr/ConnectTimeout=10/, 'ssh_opts includes ConnectTimeout=10');
    like($call_args[0]->{ssh_opts}, qr/strictHostKeyChecking=no/, 'ssh_opts includes strictHostKeyChecking=no');
};

subtest '[wait_for_ssh_login] timeout/delay/retry argument propagation' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @call_args;
    $instmod->redefine(ssh_script_retry => sub {
            my $self = shift;
            my $cmd = shift;
            my (%args) = @_;
            push @call_args, \%args;
            return 0; });
    my $provider = Test::MockObject->new;
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    # Explicit timeout propagates and drives retry = timeout/delay
    $inst->wait_for_ssh_login(timeout => 600);
    is($call_args[-1]->{delay}, 30, 'delay still defaults to 30');
    is($call_args[-1]->{retry}, 600 / 30, 'retry scales with custom timeout (20)');
    like($call_args[-1]->{fail_message}, qr/30 attempts in 600 seconds/, 'fail_message reflects custom timeout');

    # Explicit delay propagates and drives retry = timeout/delay
    $inst->wait_for_ssh_login(delay => 10);
    is($call_args[-1]->{delay}, 10, 'custom delay forwarded');

    # PUBLIC_CLOUD_SSH_TIMEOUT var overrides the default timeout
    set_var('PUBLIC_CLOUD_SSH_TIMEOUT', 900);
    $inst->wait_for_ssh_login();
    is($call_args[-1]->{retry}, 900 / 30, 'retry derives from PUBLIC_CLOUD_SSH_TIMEOUT var');
    set_var('PUBLIC_CLOUD_SSH_TIMEOUT', undef);
};
done_testing;
