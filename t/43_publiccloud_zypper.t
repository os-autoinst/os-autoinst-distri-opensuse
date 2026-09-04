# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::zypper -- verb classification,
# zypper->transactional-update translation, argument normalization and the
# public package-management API (with the remote SSH layer mocked out).
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::zypper qw(
  pc_zypper_call
  pc_transactional_call
  pc_pkg_call
  pc_refresh
  pc_add_repo
  pc_wait_quit
  pc_wait_quit_local
  pc_installed_packages
  pc_available_packages
  pc_install_packages_local
  EXIT_LOCKED
  EXIT_REPOS_SKIPPED
  EXIT_TIMEOUT
  EXIT_TIMEOUT_KILLED
);

# ---------------------------------------------------------------------------
# Pure helpers: _shell_quote
# ---------------------------------------------------------------------------
subtest '[_shell_quote] wraps and escapes' => sub {
    is(publiccloud::zypper::_shell_quote('abc'), q{'abc'}, 'simple string wrapped in single quotes');
    is(publiccloud::zypper::_shell_quote(q{a'b}), q{'a'\''b'}, "embedded single quote escaped");
    is(publiccloud::zypper::_shell_quote(''), q{''}, 'empty string yields empty quotes');
};

# ---------------------------------------------------------------------------
# Pure helpers: _verb_of
# ---------------------------------------------------------------------------
subtest '[_verb_of] strips leading options' => sub {
    is(publiccloud::zypper::_verb_of('in curl'), 'in', 'plain verb');
    is(publiccloud::zypper::_verb_of('-n in curl'), 'in', 'leading global option skipped');
    is(publiccloud::zypper::_verb_of('--no-selfupdate -n up'), 'up', 'multiple leading options skipped');
    is(publiccloud::zypper::_verb_of('--gpg-auto-import-keys ref'), 'ref', 'option before ref');
};

# ---------------------------------------------------------------------------
# Pure helpers: _is_translatable_to_transactional
# ---------------------------------------------------------------------------
subtest '[_is_translatable_to_transactional] verb allow-list' => sub {
    ok publiccloud::zypper::_is_translatable_to_transactional('in curl'), 'install is translatable';
    ok publiccloud::zypper::_is_translatable_to_transactional('rm pkg'), 'remove is translatable';
    ok publiccloud::zypper::_is_translatable_to_transactional('up'), 'up is translatable';
    ok publiccloud::zypper::_is_translatable_to_transactional('dup'), 'dup is translatable';
    ok publiccloud::zypper::_is_translatable_to_transactional('patch'), 'patch is translatable';
    ok !publiccloud::zypper::_is_translatable_to_transactional('ref'), 'refresh is NOT translatable';
    ok !publiccloud::zypper::_is_translatable_to_transactional('info foo'), 'info is NOT translatable';
    ok !publiccloud::zypper::_is_translatable_to_transactional('addrepo x y'), 'addrepo is NOT translatable';
};

# ---------------------------------------------------------------------------
# Pure helpers: _zypper_to_transactional
# ---------------------------------------------------------------------------
subtest '[_zypper_to_transactional] verb + option routing' => sub {
    is(publiccloud::zypper::_zypper_to_transactional('in curl'),
        'pkg install curl', 'install maps to pkg install');
    is(publiccloud::zypper::_zypper_to_transactional('rm oldpkg'),
        'pkg remove oldpkg', 'rm maps to pkg remove');
    is(publiccloud::zypper::_zypper_to_transactional('up'),
        'up', 'bare up stays top-level');
    is(publiccloud::zypper::_zypper_to_transactional('up somepkg'),
        'pkg update somepkg', 'up with args maps to pkg update');
    is(publiccloud::zypper::_zypper_to_transactional('dup'),
        'dup', 'bare dup stays top-level');
    is(publiccloud::zypper::_zypper_to_transactional('patch'),
        'patch', 'bare patch stays top-level');

    # command options stay with the verb, only TU global options are hoisted
    is(publiccloud::zypper::_zypper_to_transactional('in -y docker'),
        'pkg install -y docker', 'command flag -y stays after verb');
    is(publiccloud::zypper::_zypper_to_transactional('-n in curl'),
        '-n pkg install curl', 'recognised global -n hoisted before pkg');
    is(publiccloud::zypper::_zypper_to_transactional('--no-recommends in foo'),
        'pkg install --no-recommends foo', 'unrecognised leading flag carried with verb args');
};

subtest '[_zypper_to_transactional] unsupported verbs die' => sub {
    throws_ok { publiccloud::zypper::_zypper_to_transactional('ref') }
    qr/not supported by transactional-update/, 'refresh cannot be translated';
    throws_ok { publiccloud::zypper::_zypper_to_transactional('dup somepkg') }
    qr/does not support 'dup' with package arguments/, 'dup with pkgs dies';
};

# ---------------------------------------------------------------------------
# Pure helpers: _normalize_call_args
# ---------------------------------------------------------------------------
subtest '[_normalize_call_args] positional and named forms' => sub {
    my $inst = Test::MockObject->new;

    my ($i, $cmd, %opts) = publiccloud::zypper::_normalize_call_args($inst, 'in curl', retry => 3);
    is($cmd, 'in curl', 'positional cmd extracted');
    is($opts{retry}, 3, 'options preserved with positional cmd');

    ($i, $cmd, %opts) = publiccloud::zypper::_normalize_call_args($inst, cmd => 'up', timeout => 99);
    is($cmd, 'up', 'named cmd extracted');
    is($opts{timeout}, 99, 'options preserved with named cmd');

    ($i, $cmd, %opts) = publiccloud::zypper::_normalize_call_args($inst, retry => 1, delay => 2);
    is($cmd, undef, 'no cmd when only option pairs given');
};

# ---------------------------------------------------------------------------
# Pure helpers: _validate_args
# ---------------------------------------------------------------------------
subtest '[_validate_args] guards' => sub {
    lives_ok { publiccloud::zypper::_validate_args('in curl', {}) } 'valid cmd passes';
    throws_ok { publiccloud::zypper::_validate_args(undef, {}) }
    qr/Empty 'cmd' argument/, 'undef cmd dies';
    throws_ok { publiccloud::zypper::_validate_args('', {}) }
    qr/Empty 'cmd' argument/, 'empty cmd dies';
    throws_ok { publiccloud::zypper::_validate_args('up', {timeout => 0}) }
    qr/Invalid value 'timeout' = 0/, 'timeout 0 dies';
    throws_ok { publiccloud::zypper::_validate_args('lr | grep foo', {}) }
    qr/Exit code is from PIPESTATUS/, 'pipe to grep dies';
    lives_ok { publiccloud::zypper::_validate_args(q{`cmd` | grep foo}, {}) }
    'backtick before grep is allowed';
};

# ---------------------------------------------------------------------------
# Public API (SSH layer mocked)
# ---------------------------------------------------------------------------

# Build an instance mock that records the commands dispatched via the various
# ssh_* entry points.
#
# C<run_rc> may be a plain scalar (every ssh_script_run call returns it) or an
# arrayref used as a per-call queue (each call shifts the next value off,
# repeating the last entry once exhausted) -- handy for simulating "fails N
# times, then succeeds" retry scenarios.
#
# C<grep_rc> is the exit code returned for the internal C<sudo grep ...> log
# probes (used by _handle_transient_failure to detect lock messages); it
# defaults to 1 ("pattern not found"). Set it to 0 to simulate a match.
sub _instance_mock {
    my (%behaviour) = @_;
    my $inst = Test::MockObject->new;
    $inst->{calls} = [];
    my @run_rc_queue = ref $behaviour{run_rc} eq 'ARRAY' ? @{$behaviour{run_rc}} : ();
    $inst->mock(ssh_script_retry => sub { my ($s, %a) = @_; push @{$s->{calls}}, {m => 'retry', %a}; return 0 });
    $inst->mock(ssh_assert_script_run => sub { my ($s, %a) = @_; push @{$s->{calls}}, {m => 'assert', %a}; return 0 });
    $inst->mock(ssh_script_run => sub {
            my $s = shift;
            # Supports both cmd => '...' and a bare positional command (the
            # latter used internally by _log_grep/_last_zypper_session).
            my @rest = @_;
            my $pos_cmd = (@rest % 2) ? shift(@rest) : undef;
            my %a = @rest;
            $a{cmd} = $pos_cmd if defined $pos_cmd;
            push @{$s->{calls}}, {m => 'run', %a};
            return $behaviour{grep_rc} // 1 if defined $a{cmd} && $a{cmd} =~ /^sudo grep /;    # "not found" by default
            return shift(@run_rc_queue) if @run_rc_queue > 1;
            return $run_rc_queue[0] if @run_rc_queue;
            return $behaviour{run_rc} // 0;
    });
    $inst->mock(ssh_script_output => sub {
            my $s = shift;
            my @rest = @_;
            my $pos_cmd = (@rest % 2) ? shift(@rest) : undef;
            my %a = @rest;
            $a{cmd} = $pos_cmd if defined $pos_cmd;
            push @{$s->{calls}}, {m => 'output', %a};
            return $behaviour{output} // '';
    });
    $inst->mock(upload_log => sub { push @{$_[0]->{calls}}, {m => 'upload_log'}; return 1 });
    $inst->mock(softreboot => sub { push @{$_[0]->{calls}}, {m => 'softreboot'}; return });
    $inst->mock(upload_log => sub { push @{$_[0]->{calls}}, {m => 'upload_log', log => $_[1]}; return });
    return $inst;
}

subtest '[pc_zypper_call] prefixes sudo zypper -n' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    my $captured;
    $mod->redefine(_run => sub { my ($inst, $full, %o) = @_; $captured = $full; return 0 });
    my $inst = _instance_mock();

    pc_zypper_call($inst, 'ref');

    is($captured, 'sudo zypper -n ref', 'command wrapped with sudo zypper -n');
};

# ---------------------------------------------------------------------------
# _run / _retry_loop: resilience against SSH-level stalls and repo/credential
# hiccups right after registration (poo#204057)
#
# Unlike the subtests above, these exercise the real _run/_retry_loop/
# _handle_transient_failure code (only record_info is stubbed out, since it
# needs a live $autotest::current_test which unit tests don't have).
# ---------------------------------------------------------------------------

subtest '[pc_zypper_call] _run enables apply_graceful_timeout by default' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => 0);
    pc_zypper_call($inst, 'ref', retry => 1, delay => 0);
    my ($call) = grep { $_->{m} eq 'run' } @{$inst->{calls}};
    ok($call, 'ssh_script_run invoked');
    is($call->{apply_graceful_timeout}, 1,
        'apply_graceful_timeout defaults on so a stalled SSH call cannot bypass the retry loop (poo#204057)');
};

subtest '[pc_zypper_call] _run apply_graceful_timeout can still be disabled explicitly' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => 0);
    pc_zypper_call($inst, 'ref', retry => 1, delay => 0, apply_graceful_timeout => 0);
    my ($call) = grep { $_->{m} eq 'run' } @{$inst->{calls}};
    is($call->{apply_graceful_timeout}, 0, 'caller override is respected');
};

subtest '[pc_zypper_call] _handle_transient_failure EXIT_TIMEOUT / EXIT_TIMEOUT_KILLED are retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });

    for my $code (EXIT_TIMEOUT, EXIT_TIMEOUT_KILLED) {
        my $inst = _instance_mock(run_rc => [$code, 0]);
        my $ret = pc_zypper_call($inst, 'ref', retry => 2, delay => 0);
        is($ret, 0, "exit $code is retried and the retry succeeds");
        my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n ref' } @{$inst->{calls}};
        is(scalar @attempts, 2, "exactly 2 attempts made for exit $code (no premature die)");
    }
};

subtest '[pc_zypper_call] _handle_transient_failure EXIT_TIMEOUT dies once retries are exhausted' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => EXIT_TIMEOUT);
    throws_ok { pc_zypper_call($inst, 'ref', retry => 2, delay => 0) }
    qr/failed with code: @{[EXIT_TIMEOUT]}/,
      'still dies with the timeout exit code once every retry has been used up';
    my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n ref' } @{$inst->{calls}};
    is(scalar @attempts, 2, 'used all configured retries before giving up');
};

subtest '[pc_refresh] always plain zypper with gpg auto import' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    my ($cmd, %opts_seen);
    $mod->redefine(pc_zypper_call => sub { my ($inst, $c, %o) = @_; $cmd = $c; %opts_seen = %o; return 0 });
    my $inst = _instance_mock();
    pc_refresh($inst);
    is($cmd, '--gpg-auto-import-keys ref', 'refresh uses gpg-auto-import-keys ref');
    is($opts_seen{retry}, 3, 'default retry=3');
    is($opts_seen{delay}, 60, 'default delay=60');
    is($opts_seen{timeout}, 90, 'default timeout=90');
};

subtest '[pc_add_repo] uses ssh_assert_script_run' => sub {
    my $inst = _instance_mock();
    pc_add_repo($inst, 'myrepo', 'http://example.com/repo', timeout => 123);
    my ($call) = grep { $_->{m} eq 'assert' } @{$inst->{calls}};
    ok($call, 'ssh_assert_script_run invoked');
    is($call->{cmd}, 'sudo zypper -n addrepo -fG http://example.com/repo myrepo', 'addrepo command composed');
    is($call->{timeout}, 123, 'timeout forwarded');
};

subtest '[pc_pkg_call] routing transactional vs plain' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    my %seen;
    $mod->redefine(pc_transactional_call => sub { my ($i, $c, %o) = @_; $seen{transactional} = $c; return 0 });
    $mod->redefine(pc_zypper_call => sub { my ($i, $c, %o) = @_; $seen{zypper} = $c; return 0 });
    my $inst = _instance_mock();

    # transactional + translatable verb -> transactional path
    %seen = ();
    $mod->redefine(is_transactional => sub { 1 });
    pc_pkg_call($inst, 'in -y docker');
    is($seen{transactional}, 'pkg install -y docker', 'translatable verb routed to transactional-update');
    ok(!defined $seen{zypper}, 'plain zypper not used');

    # transactional + non-translatable verb -> plain zypper
    %seen = ();
    pc_pkg_call($inst, 'info foo');
    is($seen{zypper}, 'info foo', 'non-translatable verb falls through to plain zypper');
    ok(!defined $seen{transactional}, 'transactional path not used for info');

    # non-transactional -> always plain zypper
    %seen = ();
    $mod->redefine(is_transactional => sub { 0 });
    pc_pkg_call($inst, 'in -y docker');
    is($seen{zypper}, 'in -y docker', 'non-transactional host uses plain zypper verbatim');
    ok(!defined $seen{transactional}, 'no translation on non-transactional host');
};

subtest '[pc_pkg_call] _handle_transient_failure EXIT_REPOS_SKIPPED (106) fails immediately, not retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $mod->redefine(is_transactional => sub { 0 });

    my $inst = _instance_mock(run_rc => EXIT_REPOS_SKIPPED);
    throws_ok { pc_pkg_call($inst, 'in -y docker', retry => 3, delay => 0) }
    qr/failed with code: 106.*poo#204057/s,
      'dies with a poo#204057 pointer instead of silently retrying (not enough evidence yet it is safe to mask)';
    my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n in -y docker' } @{$inst->{calls}};
    is(scalar @attempts, 1, 'only the first attempt was made -- no retry');
};

sub _capture_pkg_call {
    my ($transactional, $cmd, %opts) = @_;
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(is_transactional => sub { $transactional });

    my %captured;
    $mod->redefine(pc_transactional_call => sub {
            my ($instance, $c, %o) = @_;
            $captured{transactional} = $c;
            return 0;
    });
    $mod->redefine(pc_zypper_call => sub {
            my ($instance, $c, %o) = @_;
            $captured{zypper} = $c;
            return 0;
    });

    my $inst = Test::MockObject->new;
    pc_pkg_call($inst, $cmd, %opts);
    return \%captured;
}

# These assert that zypper *command* options stay attached to the verb and are
# never hoisted into transactional-update's global slot. Regression guard for
# the case where `zypper in -y curl` became `transactional-update -y pkg ...`,
# with -y being an invalid transactional-update global option.

# Run pc_pkg_call with is_transactional() forced to $transactional and capture
# the command string handed to the transactional / plain-zypper layer.
subtest '[pc_pkg_call] command flags stay with verb, not hoisted to global' => sub {
    my %cases = (
        'in -y docker' => 'pkg install -y docker',
        'in --force-resolution -y curl' => 'pkg install --force-resolution -y curl',
        'in -r net_perf iperf' => 'pkg install -r net_perf iperf',
        'install --no-recommends foo bar' => 'pkg install --no-recommends foo bar',
        'update -y' => 'pkg update -y',
        'in libcontainers-common' => 'pkg install libcontainers-common',
        'rm -u oldpkg' => 'pkg remove -u oldpkg',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
        ok !defined $cap->{zypper}, "[$input] did not fall through to plain zypper";
    }
};

# The core regression guard: a zypper *command* flag placed BEFORE the verb must
# NOT be hoisted into transactional-update's global slot (where it is invalid).
# The old loop swept every leading dash-token into @flags; these cases prove the
# command flag now travels with the verb instead.
subtest '[pc_pkg_call] pre-verb command flag is kept with the verb' => sub {
    my %cases = (
        '-y in docker' => 'pkg install -y docker',
        '--force-resolution in curl' => 'pkg install --force-resolution curl',
        '--no-recommends install foo' => 'pkg install --no-recommends foo',
        # only the genuine global (-n) stays global; -y moves to the verb
        '-n -y in curl' => '-n pkg install -y curl',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
    }
};

subtest '[pc_pkg_call] bare top-level verbs translate without pkg wrapper' => sub {
    my %cases = (
        'up' => 'up',
        'dup' => 'dup',
        'dist-upgrade' => 'dup',
        'patch' => 'patch',
    );
    for my $input (sort keys %cases) {
        my $cap = _capture_pkg_call(1, $input);
        is $cap->{transactional}, $cases{$input},
          "[$input] -> transactional-update $cases{$input}";
    }
};

subtest '[pc_pkg_call] real transactional-update global opt is hoisted' => sub {
    # A genuine global option placed before the verb belongs in the global slot.
    my $cap = _capture_pkg_call(1, '-n in -y curl');
    is $cap->{transactional}, '-n pkg install -y curl',
      'global -n stays global; command -y stays with verb';
};

subtest '[pc_pkg_call] non-translatable verb falls through to plain zypper' => sub {
    my $cap = _capture_pkg_call(1, 'info foo');
    is $cap->{zypper}, 'info foo', 'info passed verbatim to pc_zypper_call';
    ok !defined $cap->{transactional}, 'info not routed through transactional-update';
};

subtest '[pc_pkg_call] non-transactional system always uses plain zypper' => sub {
    my $cap = _capture_pkg_call(0, 'in -y docker');
    is $cap->{zypper}, 'in -y docker', 'verbatim zypper on non-transactional host';
    ok !defined $cap->{transactional}, 'no transactional-update translation';
};

subtest '[pc_transactional_call] reboots on accepted exit code' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(_run => sub { return 0 });    # success exit code
    my $inst = _instance_mock();
    pc_transactional_call($inst, 'up');
    my ($rb) = grep { $_->{m} eq 'softreboot' } @{$inst->{calls}};
    ok($rb, 'softreboot triggered after successful transactional update');

    # no_reboot suppresses the reboot
    my $inst2 = _instance_mock();
    pc_transactional_call($inst2, 'up', no_reboot => 1);
    my ($rb2) = grep { $_->{m} eq 'softreboot' } @{$inst2->{calls}};
    ok(!$rb2, 'no_reboot suppresses softreboot');
};

subtest '[pc_installed_packages] filters to installed' => sub {
    my $inst = _instance_mock(output => 'curl|wget|');
    my $res = pc_installed_packages($inst, ['curl', 'wget', 'absent']);
    is_deeply($res, ['curl', 'wget'], 'returns only installed packages in order');

    is_deeply(pc_installed_packages($inst, []), [], 'empty input yields empty list');
    throws_ok { pc_installed_packages($inst, 'notarray') } qr/Expected arrayref/, 'non-arrayref dies';
};

subtest '[pc_installed_packages] drops not-installed noise' => sub {
    my $inst = _instance_mock(output => 'curl|package absent is not installed|');
    my $res = pc_installed_packages($inst, ['curl', 'absent']);
    is_deeply($res, ['curl'], 'is not installed entries filtered out');
};

subtest '[pc_available_packages] returns not-installed but available' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    # 'curl' installed; 'wget' missing but available per zypper info output
    $mod->redefine(pc_installed_packages => sub { ['curl'] });
    my $inst = _instance_mock(output => "Name : wget\nName : other\n");
    my $res = pc_available_packages($inst, ['curl', 'wget']);
    is_deeply($res, ['wget', 'other'], 'parses Name: lines from zypper info');

    # everything already installed -> empty (no zypper info call needed)
    $mod->redefine(pc_installed_packages => sub { ['curl', 'wget'] });
    is_deeply(pc_available_packages($inst, ['curl', 'wget']), [], 'all installed yields empty list');

    throws_ok { pc_available_packages($inst, 'x') } qr/Expected arrayref/, 'non-arrayref dies';
};

subtest '[pc_install_packages_local] transactional vs plain' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    # non-transactional -> utils::zypper_call
    $mod->redefine(is_transactional => sub { 0 });
    my $utils = Test::MockModule->new('utils', no_auto => 1);
    my $zypper_cmd;
    $utils->redefine(zypper_call => sub { $zypper_cmd = $_[0]; return 0 });

    pc_install_packages_local(['curl', 'wget']);

    is($zypper_cmd, 'in curl wget', 'plain install uses utils::zypper_call');

    # transactional -> trup_call + reboot_on_changes
    $mod->redefine(is_transactional => sub { 1 });
    my $trans = Test::MockModule->new('transactional', no_auto => 1);
    my ($trup, $rebooted);
    $trans->redefine(trup_call => sub { $trup = $_[0]; return 0 });
    $trans->redefine(reboot_on_changes => sub { $rebooted = 1; return 0 });

    pc_install_packages_local(['docker']);

    is($trup, 'pkg install docker', 'transactional uses trup_call');
    ok($rebooted, 'reboot_on_changes called on transactional host');

    # empty list is a no-op
    $zypper_cmd = undef;
    $mod->redefine(is_transactional => sub { 0 });
    pc_install_packages_local([]);
    ok(!defined $zypper_cmd, 'empty package list is a no-op');

    throws_ok { pc_install_packages_local('x') } qr/Expected arrayref/, 'non-arrayref dies';
};

# ---------------------------------------------------------------------------
# pc_wait_quit / pc_wait_quit_local -- poo#204534
# ---------------------------------------------------------------------------
subtest '[BUSY_PROCESS_PATTERN] transactional-update is truncated to avoid pgrep comm truncation' => sub {
    my $pattern = publiccloud::zypper::BUSY_PROCESS_PATTERN();
    # Regression guard for poo#204534: pgrep (without -f) truncates comm to
    # 15 chars, so the full 20-char literal would silently never match.
    # Assert the truncated prefix is used instead of the untruncated name.
    unlike($pattern, qr/\|transactional-update(\||$)/, 'full untruncated name is not used as a pgrep branch');
    like($pattern, qr/\|transactional-u(\||$)/, 'truncated 15-char prefix is used instead');
    like($pattern, qr/\bsnapper\b/, 'pattern includes snapper');
    like($pattern, qr/\bzypper\b/, 'pattern still includes zypper');
};

subtest '[pc_wait_quit] pgrep pattern covers transactional-update/snapper' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock();

    pc_wait_quit($inst);

    my ($call) = grep { $_->{m} eq 'retry' } @{$inst->{calls}};
    ok($call, 'ssh_script_retry invoked');
    like($call->{cmd}, qr/pgrep/, 'command greps processes');
    like($call->{cmd}, qr/\Q@{[publiccloud::zypper::BUSY_PROCESS_PATTERN()]}\E/, 'uses the shared busy-process pattern');
};

subtest '[pc_wait_quit_local] polls via plain script_retry, no SSH' => sub {
    my $utils = Test::MockModule->new('utils', no_auto => 1);
    my ($cmd, %opts_seen);
    $utils->redefine(script_retry => sub { $cmd = $_[0]; %opts_seen = @_[1 .. $#_]; return 0 });

    pc_wait_quit_local(timeout => 5, delay => 1, retry => 2);

    like($cmd, qr/pgrep/, 'command greps processes');
    like($cmd, qr/\Q@{[publiccloud::zypper::BUSY_PROCESS_PATTERN()]}\E/, 'uses the shared busy-process pattern');
    is($opts_seen{timeout}, 5, 'timeout forwarded');
    is($opts_seen{delay}, 1, 'delay forwarded');
    is($opts_seen{retry}, 2, 'retry forwarded');
};

# ---------------------------------------------------------------------------
# transactional-update lock detection (poo#204534) and zypp-lock retry,
# exercised through the public pc_transactional_call / pc_zypper_call API
# rather than the internal _handle_transient_failure helper.
# ---------------------------------------------------------------------------
subtest '[pc_transactional_call] transactional-update lock message triggers a retry (poo#204534)' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    # First attempt fails; the lock grep on transactional-update.log matches
    # (grep_rc => 0), so the failure is treated as transient and retried; the
    # second attempt succeeds.
    my $inst = _instance_mock(run_rc => [1, 0], grep_rc => 0);

    my $ret = pc_transactional_call($inst, 'up', retry => 2, delay => 0);

    is($ret, 0, 'retries when the log confirms a lock, then succeeds');
    my @attempts = grep { $_->{m} eq 'run' && ($_->{cmd} // '') eq 'sudo transactional-update -n up' } @{$inst->{calls}};
    is(scalar @attempts, 2, 'exactly 2 attempts made (retried once)');

    # The lock-detection grep must target transactional-update.log and cover
    # both independent lock messages (CLI bashlock and tukit backend).
    my ($grep) = grep { $_->{m} eq 'run' && ($_->{cmd} // '') =~ /^sudo grep / } @{$inst->{calls}};
    ok($grep, 'a lock-detection grep was issued');
    like($grep->{cmd}, qr{/var/log/transactional-update\.log}, 'greps transactional-update.log');
    like($grep->{cmd}, qr/get lock/, 'checks the CLI bashlock message');
    like($grep->{cmd}, qr/Another instance of tukit is already running/, 'checks the tukit backend message');
};

subtest '[pc_transactional_call] transactional-update failure without a lock message is not retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    # Every attempt fails and the lock grep never matches (grep_rc default 1),
    # so this is a genuine failure that must surface instead of being retried.
    my $inst = _instance_mock(run_rc => 1);

    throws_ok { pc_transactional_call($inst, 'up', retry => 3, delay => 0) }
    qr/failed with code: 1/, 'a genuine transactional-update failure dies';
    my @attempts = grep { $_->{m} eq 'run' && ($_->{cmd} // '') eq 'sudo transactional-update -n up' } @{$inst->{calls}};
    is(scalar @attempts, 1, 'only the first attempt was made -- no retry');
};

subtest '[pc_zypper_call] EXIT_LOCKED (zypp lock) is retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper', no_auto => 1);
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    # Unlike the transactional case, a zypp lock (exit 7) is always transient
    # and retried without needing a log confirmation.
    my $inst = _instance_mock(run_rc => [EXIT_LOCKED, 0]);

    my $ret = pc_zypper_call($inst, 'ref', retry => 2, delay => 0);

    is($ret, 0, 'EXIT_LOCKED is retried and the retry succeeds');
    my @attempts = grep { $_->{m} eq 'run' && ($_->{cmd} // '') eq 'sudo zypper -n ref' } @{$inst->{calls}};
    is(scalar @attempts, 2, 'exactly 2 attempts made (retried once)');
};

sub _instance_mock_positional {
    my $inst = Test::MockObject->new;
    $inst->{calls} = [];
    $inst->mock(ssh_script_run => sub { my ($s, $cmd) = @_; push @{$s->{calls}}, $cmd; return 0 });
    $inst->mock(ssh_script_output => sub { return 'some log tail' });
    $inst->mock(upload_log => sub { return });
    return $inst;
}

subtest '[_log_grep] defaults to zypper log, accepts an override, uses extended regex' => sub {
    my $inst = _instance_mock_positional();
    publiccloud::zypper::_log_grep($inst, 'needle');
    like($inst->{calls}[0], qr{/var/log/zypper\.log}, 'defaults to zypper.log');
    like($inst->{calls}[0], qr/grep -E/, 'uses -E so callers can use plain alternation');

    $inst = _instance_mock_positional();
    publiccloud::zypper::_log_grep($inst, 'needle', '/var/log/transactional-update.log');
    like($inst->{calls}[0], qr{/var/log/transactional-update\.log}, 'custom log path honoured');
};

subtest '[_report_failure] uses transactional-update.log for transactional kind' => sub {
    my $inst = _instance_mock_positional();
    throws_ok { publiccloud::zypper::_report_failure($inst, 'transactional-update -n up', 1, 0, 'transactional') }
    qr/Related transactional-update logs/, 'error message references the right log';
    my ($chmod_cmd) = grep { /chmod/ } @{$inst->{calls}};
    like($chmod_cmd, qr{/var/log/transactional-update\.log}, 'chmod targets transactional-update.log');
};

subtest '[pc_wait_quit] uses defaults and expected command' => sub {
    my $inst = Test::MockObject->new;
    my @calls;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            push @calls, {%args};
            return 1;
    });

    pc_wait_quit($inst);

    is scalar(@calls), 1, 'one call to ssh_script_retry';
    is $calls[0]->{cmd},
      q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"},
      'expected pgrep/false/true command';
    is $calls[0]->{timeout}, 20, 'default timeout=20';
    is $calls[0]->{delay}, 10, 'default delay=10';
    is $calls[0]->{retry}, 120, 'default retry=120';
};

subtest '[pc_wait_quit] honors custom timeout/delay/retry' => sub {
    my $inst = Test::MockObject->new;
    my $seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            $seen = {%args};
            return 1;
    });

    pc_wait_quit($inst,
        timeout => 5, delay => 2, retry => 3);

    is $seen->{cmd},
      q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"},
      'same command with custom args';
    is $seen->{timeout}, 5, 'custom timeout applied';
    is $seen->{delay}, 2, 'custom delay applied';
    is $seen->{retry}, 3, 'custom retry applied';
};

subtest '[pc_wait_quit] succeeds on 5th attempt (4 fail + 1 success)' => sub {
    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
                last if $calls == 5;
            }
            return 1;
    });

    my $rc = pc_wait_quit($inst, retry => 5, delay => 0, timeout => 1);

    ok($rc, 'returned success');
    is($calls, 5, 'performed 5 attempts (4 fail + 1 success)');
    is($seen{retry}, 5, 'retry=5 passed');
    is($seen{delay}, 0, 'delay=0 passed');
    is($seen{timeout}, 1, 'timeout=1 passed');
};

subtest '[pc_wait_quit] times out after 5 failures' => sub {
    my $expected_cmd = q{! pgrep -a "} . publiccloud::zypper::BUSY_PROCESS_PATTERN() . q{"};

    my $inst = Test::MockObject->new;
    my $calls = 0;
    my %seen;

    $inst->mock('ssh_script_retry', sub {
            my ($self, %args) = @_;
            %seen = %args;

            while ($calls < $args{retry}) {
                $calls++;
            }
            die "retries exhausted after $args{retry} attempts\n";
    });

    my $err;
    eval {
        pc_wait_quit($inst, retry => 5, delay => 0, timeout => 1);
        1;
    } or $err = $@;

    like($err, qr/retries exhausted after 5 attempts/, 'died with timeout message');
    is($calls, 5, 'performed 5 failing attempts');
    is($seen{cmd}, $expected_cmd, 'used expected pgrep command');
    is($seen{retry}, 5, 'retry=5 passed');
    is($seen{delay}, 0, 'delay=0 passed');
    is($seen{timeout}, 1, 'timeout=1 passed');
};

done_testing;
