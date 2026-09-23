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
use List::Util qw(any);
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

subtest '[wait_for_sudo] probes sudo over a non-multiplexed connection' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my ($cmd, %args);
    $instmod->redefine(ssh_script_retry => sub { (my $self, $cmd, %args) = @_; return 0; });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', provider => Test::MockObject->new);

    $inst->wait_for_sudo();
    is($cmd, 'sudo -n true', 'probes passwordless sudo non-interactively');
    # group membership is resolved at login, so a ControlMaster opened before
    # the sudoers group was added would never see it
    like($args{ssh_opts}, qr/ControlPath=none/, 'does not reuse an existing ssh master connection');
};

# Mock the three steps of wait_for_ssh and record, in call order, what each one
# received. Returns the list of recorded calls and keeps the mock alive in $mod.
sub mock_wait_for_ssh_steps {
    my ($mod, $calls) = @_;
    $mod->redefine(script_retry => sub { my ($cmd, %a) = @_; push @$calls, {step => 'nc', cmd => $cmd, args => \%a}; return 0; });
    $mod->redefine(ssh_script_retry => sub { my ($self, $cmd, %a) = @_; push @$calls, {step => 'ssh', cmd => $cmd, args => \%a}; return 0; });
    $mod->redefine(scan_ssh_host_key => sub { my ($self, %a) = @_; push @$calls, {step => 'scan', args => \%a}; return 0; });
}

subtest '[wait_for_ssh] timeout, delay and retry for argument and PUBLIC_CLOUD_SSH_TIMEOUT combinations' => sub {
    my @cases = (
        {name => 'all defaults', args => {}, delay => 30, retry => 10},
        {name => 'PUBLIC_CLOUD_SSH_TIMEOUT used without timeout argument', var => 600, args => {}, delay => 30, retry => 20},
        {name => 'timeout argument without PUBLIC_CLOUD_SSH_TIMEOUT', args => {timeout => 90}, delay => 30, retry => 3},
        {name => 'timeout argument wins over PUBLIC_CLOUD_SSH_TIMEOUT', var => 600, args => {timeout => 120}, delay => 30, retry => 4},
        {name => 'delay argument with default timeout', args => {delay => 10}, delay => 10, retry => 30},
        {name => 'delay argument with PUBLIC_CLOUD_SSH_TIMEOUT', var => 400, args => {delay => 20}, delay => 20, retry => 20},
        {name => 'timeout and delay arguments', var => 600, args => {timeout => 60, delay => 5}, delay => 5, retry => 12},
    );

    foreach my $case (@cases) {
        my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
        my @calls;
        mock_wait_for_ssh_steps($instmod, \@calls);
        set_var('PUBLIC_CLOUD_SSH_TIMEOUT', $case->{var});
        my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

        $inst->wait_for_ssh(%{$case->{args}});
        set_var('PUBLIC_CLOUD_SSH_TIMEOUT', undef);

        is(scalar @calls, 2, "$case->{name}: only the nc and ssh steps run");
        my ($nc, $ssh) = @calls;
        is($nc->{step}, 'nc', "$case->{name}: port is probed first");
        is($ssh->{step}, 'ssh', "$case->{name}: ssh login is probed second");
        for my $step ($nc, $ssh) {
            is($step->{args}{delay}, $case->{delay}, "$case->{name}: $step->{step} delay is $case->{delay}");
            is($step->{args}{retry}, $case->{retry}, "$case->{name}: $step->{step} retry is $case->{retry}");
        }
    }
};

subtest '[wait_for_ssh] probed commands and port' => sub {
    my @cases = (
        {name => 'default port', args => {}, port => 22},
        {name => 'custom port', args => {port => 2222}, port => 2222},
    );

    foreach my $case (@cases) {
        my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
        my @calls;
        mock_wait_for_ssh_steps($instmod, \@calls);
        my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

        $inst->wait_for_ssh(%{$case->{args}});

        like($calls[0]{cmd}, qr/^nc -vz -w 1 10\.0\.0\.1 $case->{port}$/, "$case->{name}: nc probes the instance ip on port $case->{port}");
        is($calls[1]{cmd}, 'true', "$case->{name}: ssh login runs 'true'");
    }
};

subtest '[wait_for_ssh] ssh login uses ssh_opts without modifying it' => sub {
    my @cases = (
        {name => 'empty ssh_opts', ssh_opts => ''},
        {name => 'custom ssh_opts', ssh_opts => '-i /root/.ssh/id_rsa -o LogLevel=ERROR'},
    );

    foreach my $case (@cases) {
        my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
        my @calls;
        mock_wait_for_ssh_steps($instmod, \@calls);
        my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u', ssh_opts => $case->{ssh_opts});

        $inst->wait_for_ssh();

        my $opts = $calls[1]{args}{ssh_opts};
        note("ssh_opts --> $opts");
        like($opts, qr/^\Q$case->{ssh_opts}\E/, "$case->{name}: starts with the instance ssh_opts");
        like($opts, qr/-o ControlPath=none/, "$case->{name}: does not reuse an existing ssh master connection");
        like($opts, qr/-o strictHostKeyChecking=no/, "$case->{name}: host key checking is relaxed");
        like($opts, qr/-o UserKnownHostsFile=\/dev\/null/, "$case->{name}: known_hosts is not used");
        is($inst->ssh_opts, $case->{ssh_opts}, "$case->{name}: instance ssh_opts is unchanged");
    }
};

subtest '[wait_for_ssh] scan_ssh_host_key' => sub {
    my @cases = (
        {name => 'not requested', args => {}, scan => 0},
        {name => 'enabled with defaults', args => {scan_ssh_host_key => 1}, scan => 1, timeout => 300},
        {name => 'enabled with timeout, delay and port', args => {scan_ssh_host_key => 1, timeout => 60, delay => 5, port => 2222}, scan => 1, timeout => 60},
    );

    foreach my $case (@cases) {
        my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
        my @calls;
        mock_wait_for_ssh_steps($instmod, \@calls);
        set_var('PUBLIC_CLOUD_SSH_TIMEOUT', $case->{var});
        my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

        $inst->wait_for_ssh(%{$case->{args}});
        set_var('PUBLIC_CLOUD_SSH_TIMEOUT', undef);

        my @scans = grep { $_->{step} eq 'scan' } @calls;
        is(scalar @scans, $case->{scan}, "$case->{name}: scan_ssh_host_key called $case->{scan} time(s)");
        next unless $case->{scan};
        is($calls[-1]{step}, 'scan', "$case->{name}: scan runs after the nc and ssh steps");
        is($scans[0]{args}{timeout}, $case->{timeout}, "$case->{name}: scan gets the resolved timeout $case->{timeout}");
        is($scans[0]{args}{$_}, $case->{args}{$_}, "$case->{name}: scan gets the $_ argument") for sort keys %{$case->{args}};
    }
};

subtest '[wait_for_ssh] stops when a step fails' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my @calls;
    mock_wait_for_ssh_steps($instmod, \@calls);
    $instmod->redefine(script_retry => sub { push @calls, {step => 'nc'}; die "ssh port unreachable\n"; });
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');

    throws_ok { $inst->wait_for_ssh(scan_ssh_host_key => 1) } qr/ssh port unreachable/, 'dies when the port never opens';
    is_deeply([map { $_->{step} } @calls], ['nc'], 'no ssh login or host key scan after the port check fails');

    @calls = ();
    mock_wait_for_ssh_steps($instmod, \@calls);
    $instmod->redefine(ssh_script_retry => sub { push @calls, {step => 'ssh'}; die "ssh connection failed\n"; });

    throws_ok { $inst->wait_for_ssh(scan_ssh_host_key => 1) } qr/ssh connection failed/, 'dies when ssh login never succeeds';
    is_deeply([map { $_->{step} } @calls], ['nc', 'ssh'], 'no host key scan after the ssh login fails');
};

subtest '[softreboot] tolerates a hung ssh -O check during tunneled cleanup (poo#207027)' => sub {
    # A hung/unresponsive console during the pre-shutdown "ssh -O check" cleanup must not
    # fatally abort the whole test: it must be treated like "connection already gone" and
    # the reboot must still proceed.
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my %vars = (_SSH_TUNNELS_INITIALIZED => 1, SERIALDEV => 'sshserial');
    my @calls;
    # These all return unused/discarded values, or just need to be truthy -- noop's
    # always-return-1 stub covers every one of them.
    $instmod->noop(qw(is_tunneled select_console ssh_interactive_leave select_host_console
          ssh_interactive_tunnel update_instance_ip wait_for_ssh_unreachable wait_for_ssh));
    $instmod->redefine(get_var => sub { my ($key, $default) = @_; return exists $vars{$key} ? $vars{$key} : $default; });
    $instmod->redefine(current_console => sub { 'tunnel-console' });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $instmod->redefine(script_run => sub {
            my ($cmd) = @_;
            push @calls, $cmd;
            die "command '$cmd' timed out\n" if ($cmd =~ /-O check/);
            return 0;
    });
    $instmod->redefine(assert_script_run => sub { push @calls, $_[0]; return 0; });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'azureuser', provider => Test::MockObject->new);

    lives_ok { $inst->softreboot() } 'a hung ssh -O check does not fatally abort softreboot';
    is((grep { /-O check/ } @calls), 1, 'ssh -O check was attempted exactly once, not retried against a dead console');
    ok((any { /-O exit/ } @calls), 'ssh -O exit is still attempted even after a hung check');
    ok((any { /shutdown -r \+1/ } @calls), 'the reboot is still triggered after the hung check');
};

$autotest::current_test = {name => 'wait_for_guestregister_test'};

subtest '[wait_for_guestregister] failed records a soft failure (bsc#1264275)' => sub {
    # wait_for_guestregister -- diagnostics (log + full journal) must be captured on every failure path (poo#204360)
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my (@uploads, @calls, @softfails);
    $instmod->redefine(ssh_script_run => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 0 });
    $instmod->redefine(ssh_script_output => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 'guestregister.service - failed' });
    $instmod->redefine(upload_log => sub { my ($self, $log, %args) = @_; push @uploads, [$log, \%args] });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $instmod->redefine(record_soft_failure => sub { push @softfails, $_[0] });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    is($inst->wait_for_guestregister(), 1, 'returns 1 instead of dying');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is(scalar @uploads, 2, 'upload_log called for the cloudregister log and the guestregister journal');
    is($uploads[0][0], '/var/log/cloudregister', 'uploads /var/log/cloudregister');
    ok((any { /journalctl -u guestregister\.service/ } @calls), 'journal command targets guestregister.service');
    is(scalar @softfails, 1, 'records exactly one soft failure');
    like($softfails[0], qr/bsc#1264275/, 'soft failure references bsc#1264275');
};

subtest '[wait_for_guestregister] failed + PUBLIC_CLOUD_IGNORE_UNREGISTERED skips diagnostics' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my (@uploads, @calls);
    $instmod->redefine(ssh_script_run => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 0 });
    $instmod->redefine(ssh_script_output => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 'guestregister.service - failed' });
    $instmod->redefine(upload_log => sub { push @uploads, 1 });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });

    set_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED', 1);
    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    is($inst->wait_for_guestregister(), 1, 'returns 1 for known/expected failure');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is(scalar @uploads, 0, 'no diagnostics captured for an ignored failure');
    ok(!(any { /journalctl/ } @calls), 'journal is never queried for an ignored failure');
    set_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED', undef);
};

subtest '[wait_for_guestregister] active on BYOS captures diagnostics before dying' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my (@uploads, @calls);
    $instmod->redefine(ssh_script_run => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 0 });
    $instmod->redefine(ssh_script_output => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 'guestregister.service - active' });
    $instmod->redefine(upload_log => sub { my ($self, $log, %args) = @_; push @uploads, [$log, \%args] });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $instmod->redefine(is_byos => sub { return 1 });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    throws_ok { $inst->wait_for_guestregister() } qr/should not be active on BYOS/, 'dies for active-on-BYOS';
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is(scalar @uploads, 2, 'upload_log called for the cloudregister log and the guestregister journal');
    ok((any { /journalctl -u guestregister\.service/ } @calls), 'journal command targets guestregister.service');
};

subtest '[wait_for_guestregister] timeout captures diagnostics before dying' => sub {
    my $instmod = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    my (@uploads, @calls);
    $instmod->redefine(ssh_script_run => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 0 });
    $instmod->redefine(ssh_script_output => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 'guestregister.service - activating' });
    $instmod->redefine(upload_log => sub { my ($self, $log, %args) = @_; push @uploads, [$log, \%args] });
    $instmod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });

    my $inst = publiccloud::instance->new(public_ip => '10.0.0.1', username => 'u');
    throws_ok { $inst->wait_for_guestregister(timeout => 0) } qr/didn't end in expected timeout/, 'dies on timeout';
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is(scalar @uploads, 2, 'upload_log called for the cloudregister log and the guestregister journal');
    ok((any { /journalctl -u guestregister\.service/ } @calls), 'journal command targets guestregister.service');
};

done_testing;
