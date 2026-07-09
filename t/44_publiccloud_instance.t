# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::instance -- systemd time parsing,
# the isok helper, ssh command construction and the thin provider-delegating
# methods (start/stop/get_state/wait_for_state).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::instance;

# ---------------------------------------------------------------------------
# Pure helper: isok
# ---------------------------------------------------------------------------
subtest '[isok] shell exit code truthiness' => sub {
    ok(publiccloud::instance::isok(0), '0 is ok');
    ok(!publiccloud::instance::isok(1), '1 is not ok');
    ok(!publiccloud::instance::isok(undef), 'undef is not ok');
    ok(!publiccloud::instance::isok(255), '255 is not ok');
};

# ---------------------------------------------------------------------------
# Pure helper: systemd_time_to_second
# ---------------------------------------------------------------------------
subtest '[systemd_time_to_second] parsing' => sub {
    cmp_ok(publiccloud::instance::systemd_time_to_second('1.234s'), '==', 1.234, 'seconds only');
    cmp_ok(publiccloud::instance::systemd_time_to_second('500ms'), '==', 0.5, 'milliseconds converted');
    cmp_ok(publiccloud::instance::systemd_time_to_second('1min 30.000s'), '==', 90, 'minutes + seconds');
    cmp_ok(publiccloud::instance::systemd_time_to_second('1h 0min 0.000s'), '==', 3600, 'hours + min + sec');
    cmp_ok(publiccloud::instance::systemd_time_to_second('2h 3min 4.500s'), '==', 2 * 3600 + 3 * 60 + 4.5, 'full combination');
};

subtest '[systemd_time_to_second] invalid returns -1' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instance->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    is(publiccloud::instance::systemd_time_to_second('garbage'), -1, 'unparseable string returns -1');
    is(publiccloud::instance::systemd_time_to_second(''), -1, 'empty string returns -1');
};

# ---------------------------------------------------------------------------
# Pure helper: extract_analyze_time
# ---------------------------------------------------------------------------
subtest '[extract_analyze_time] systemd-analyze time output' => sub {
    my $out = 'Startup finished in 1.500s (kernel) + 2.000s (initrd) + 10.000s (userspace) = 13.500s';
    my $res = publiccloud::instance::extract_analyze_time($out);
    is(ref $res, 'HASH', 'returns hashref on success');
    cmp_ok($res->{kernel}, '==', 1.5, 'kernel time parsed');
    cmp_ok($res->{initrd}, '==', 2, 'initrd time parsed');
    cmp_ok($res->{userspace}, '==', 10, 'userspace time parsed');
    cmp_ok($res->{overall}, '==', 13.5, 'overall (after =) parsed');
};

subtest '[extract_analyze_time] missing component returns undef' => sub {
    # No initrd component -> incomplete -> undef
    my $out = 'Startup finished in 1.500s (kernel) + 10.000s (userspace) = 11.500s';
    is(publiccloud::instance::extract_analyze_time($out), undef, 'incomplete data returns undef');
};

# ---------------------------------------------------------------------------
# Pure helper: extract_blame_time
# ---------------------------------------------------------------------------
subtest '[extract_blame_time] systemd-analyze blame output' => sub {
    my $out = "5.000s foo.service\n2.500s bar.service";
    my $res = publiccloud::instance::extract_blame_time($out);
    is(ref $res, 'HASH', 'returns hashref');
    cmp_ok($res->{'foo.service'}, '==', 5, 'foo.service parsed');
    cmp_ok($res->{'bar.service'}, '==', 2.5, 'bar.service parsed');
};

subtest '[extract_blame_time] unparseable line returns empty hashref' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instance->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $out = "totally bogus";
    is_deeply(publiccloud::instance::extract_blame_time($out), {}, 'bad time token returns empty hashref');
};

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

subtest '[_apply_cmd_timeout] wraps with timeout when ignore_timeout_failure' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

    my %args = (timeout => 100, ignore_timeout_failure => 1);
    my $ssh_cmd = 'ssh foo';
    $inst->_apply_cmd_timeout(\%args, \$ssh_cmd);
    like($ssh_cmd, qr/^timeout --foreground -k 10s 100 ssh foo$/, 'wrapped in timeout call');
    is($args{timeout}, 120, 'script_run timeout bumped by 20s buffer');
    ok(!exists $args{ignore_timeout_failure}, 'ignore_timeout_failure consumed');

    # Without the flag: no wrapping
    my %args2 = (timeout => 50);
    my $ssh_cmd2 = 'ssh bar';
    $inst->_apply_cmd_timeout(\%args2, \$ssh_cmd2);
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

subtest '[scp] composes scp command and rewrites remote:' => sub {
    my $instance = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my $seen_cmd;
    $instance->redefine(assert_script_run => sub { $seen_cmd = $_[0]; return 0 });

    my $inst = publiccloud::instance->new(public_ip => '198.51.100.2', username => 'admin', ssh_opts => '-o X=y -E /tmp/log');
    $inst->scp('remote:/var/log/messages', '/tmp/messages');
    like($seen_cmd, qr/^scp /, 'starts with scp');
    like($seen_cmd, qr/admin\@198\.51\.100\.2:\/var\/log\/messages/, 'remote: rewritten to user@ip:');
    like($seen_cmd, qr/\/tmp\/messages/, 'destination present');
    unlike($seen_cmd, qr/-E /, '-E option stripped (scp does not accept it)');
};

subtest '[retry_ssh_command] retries then succeeds' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @rcs = (1, 1, 0);
    my $calls = 0;
    $instmod->redefine(ssh_script_run => sub { $calls++; return shift @rcs });
    # avoid real sleep
    no warnings 'redefine';
    local *publiccloud::instance::sleep = sub { };
    my $rc = $inst->retry_ssh_command(cmd => 'true', retry => 5, delay => 0);
    is($rc, 0, 'returns 0 on eventual success');
    is($calls, 3, 'stopped retrying after first success');
};

subtest '[retry_ssh_command] dies after exhausting retries' => sub {
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instmod->redefine(ssh_script_run => sub { 1 });
    no warnings 'redefine';
    local *publiccloud::instance::sleep = sub { };
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

    no warnings 'redefine';
    local *publiccloud::instance::sleep = sub { };
    lives_ok { $inst->wait_for_state('running', 100) } 'returns once desired state reached';
};

subtest '[wait_for_state] dies on timeout' => sub {
    my $provider = Test::MockObject->new;
    $provider->mock(get_state_from_instance => sub { 'pending' });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => $provider);

    no warnings 'redefine';
    local *publiccloud::instance::sleep = sub { };
    # A zero timeout makes the deadline already in the past on the first check,
    # so the method gives up immediately and dies. The die message interpolates
    # an as-yet-undef $current, so silence that expected warning.
    local $SIG{__WARN__} = sub { };
    throws_ok { $inst->wait_for_state('running', 0) }
    qr/instance state is not 'running'/, 'dies when state never matches before timeout';
};

done_testing;
