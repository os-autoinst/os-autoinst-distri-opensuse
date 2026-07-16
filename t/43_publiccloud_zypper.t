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
  pc_installed_packages
  pc_available_packages
  pc_install_packages_local
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
            return 1 if defined $a{cmd} && $a{cmd} =~ /^sudo grep /;    # "not found" by default
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
    return $inst;
}

subtest '[pc_zypper_call] prefixes sudo zypper -n' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    my $captured;
    $mod->redefine(_run => sub { my ($inst, $full, %o) = @_; $captured = $full; return 0 });
    my $inst = _instance_mock();
    pc_zypper_call($inst, 'ref');
    is($captured, 'sudo zypper -n ref', 'command wrapped with sudo zypper -n');
};

subtest '[pc_refresh] always plain zypper with gpg auto import' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
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
    my $mod = Test::MockModule->new('publiccloud::zypper');
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

subtest '[pc_transactional_call] reboots on accepted exit code' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
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
    my $mod = Test::MockModule->new('publiccloud::zypper');
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

# ---------------------------------------------------------------------------
# _run / _retry_loop: resilience against SSH-level stalls and repo/credential
# hiccups right after registration (poo#204057)
#
# Unlike the subtests above, these exercise the real _run/_retry_loop/
# _handle_transient_failure code (only record_info is stubbed out, since it
# needs a live $autotest::current_test which unit tests don't have).
# ---------------------------------------------------------------------------

subtest '[_run] enables apply_graceful_timeout by default' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => 0);
    pc_zypper_call($inst, 'ref', retry => 1, delay => 0);
    my ($call) = grep { $_->{m} eq 'run' } @{$inst->{calls}};
    ok($call, 'ssh_script_run invoked');
    is($call->{apply_graceful_timeout}, 1,
        'apply_graceful_timeout defaults on so a stalled SSH call cannot bypass the retry loop (poo#204057)');
};

subtest '[_run] apply_graceful_timeout can still be disabled explicitly' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => 0);
    pc_zypper_call($inst, 'ref', retry => 1, delay => 0, apply_graceful_timeout => 0);
    my ($call) = grep { $_->{m} eq 'run' } @{$inst->{calls}};
    is($call->{apply_graceful_timeout}, 0, 'caller override is respected');
};

subtest '[_handle_transient_failure] EXIT_TIMEOUT / EXIT_TIMEOUT_KILLED are retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });

    for my $code (EXIT_TIMEOUT, EXIT_TIMEOUT_KILLED) {
        my $inst = _instance_mock(run_rc => [$code, 0]);
        my $ret = pc_zypper_call($inst, 'ref', retry => 2, delay => 0);
        is($ret, 0, "exit $code is retried and the retry succeeds");
        my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n ref' } @{$inst->{calls}};
        is(scalar @attempts, 2, "exactly 2 attempts made for exit $code (no premature die)");
    }
};

subtest '[_handle_transient_failure] EXIT_TIMEOUT dies once retries are exhausted' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    my $inst = _instance_mock(run_rc => EXIT_TIMEOUT);
    throws_ok { pc_zypper_call($inst, 'ref', retry => 2, delay => 0) }
    qr/failed with code: @{[EXIT_TIMEOUT]}/,
      'still dies with the timeout exit code once every retry has been used up';
    my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n ref' } @{$inst->{calls}};
    is(scalar @attempts, 2, 'used all configured retries before giving up');
};

subtest '[_handle_transient_failure] EXIT_REPOS_SKIPPED (106) fails immediately, not retried' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');
    $mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)) });
    $mod->redefine(is_transactional => sub { 0 });

    my $inst = _instance_mock(run_rc => EXIT_REPOS_SKIPPED);
    throws_ok { pc_pkg_call($inst, 'in -y docker', retry => 3, delay => 0) }
    qr/failed with code: 106.*poo#204057/s,
      'dies with a poo#204057 pointer instead of silently retrying (not enough evidence yet it is safe to mask)';
    my @attempts = grep { $_->{m} eq 'run' && $_->{cmd} eq 'sudo zypper -n in -y docker' } @{$inst->{calls}};
    is(scalar @attempts, 1, 'only the first attempt was made -- no retry');
};

subtest '[pc_install_packages_local] transactional vs plain' => sub {
    my $mod = Test::MockModule->new('publiccloud::zypper');

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

done_testing;
