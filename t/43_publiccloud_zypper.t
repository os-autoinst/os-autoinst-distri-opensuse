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
sub _instance_mock {
    my (%behaviour) = @_;
    my $inst = Test::MockObject->new;
    $inst->{calls} = [];
    $inst->mock(ssh_script_retry => sub { my ($s, %a) = @_; push @{$s->{calls}}, {m => 'retry', %a}; return 0 });
    $inst->mock(ssh_assert_script_run => sub { my ($s, %a) = @_; push @{$s->{calls}}, {m => 'assert', %a}; return 0 });
    $inst->mock(ssh_script_run => sub {
            my ($s, %a) = @_;
            push @{$s->{calls}}, {m => 'run', %a};
            return $behaviour{run_rc} // 0;
    });
    $inst->mock(ssh_script_output => sub {
            my ($s, %a) = @_;
            push @{$s->{calls}}, {m => 'output', %a};
            return $behaviour{output} // '';
    });
    $inst->mock(softreboot => sub { push @{$_[0]->{calls}}, {m => 'softreboot'}; return });
    $inst->mock(upload_log => sub { push @{$_[0]->{calls}}, {m => 'upload_log', log => $_[1]}; return });
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
# _handle_transient_failure -- transactional-update lock detection (poo#204534)
# ---------------------------------------------------------------------------
subtest '[_handle_transient_failure] transactional lock message triggers retry' => sub {
    my $testapi_mock = Test::MockModule->new('publiccloud::zypper');
    $testapi_mock->redefine(record_info => sub { return 1 });
    my $inst = _instance_mock();
    $inst->mock(ssh_script_run => sub {
            my ($s, $cmd) = @_;
            push @{$s->{calls}}, {m => 'run', cmd => $cmd};
            return ($cmd =~ /transactional-update\.log/) ? 0 : 1;    # pattern found
    });
    is(publiccloud::zypper::_handle_transient_failure($inst, 1, 1, 3, 'transactional'),
        'retry', 'retries when log confirms the lock message');
};

subtest '[_handle_transient_failure] greps for both known lock messages' => sub {
    my $testapi_mock = Test::MockModule->new('publiccloud::zypper');
    $testapi_mock->redefine(record_info => sub { return 1 });

    for my $case (
        {label => 'bashlock (CLI wrapper) message', needle => 'Couldn'},
        {label => 'tukit backend message', needle => 'Another instance of tukit is already running'},
      )
    {
        my $inst = _instance_mock_positional();
        $inst->mock(ssh_script_run => sub {
                my ($s, $cmd) = @_;
                push @{$s->{calls}}, $cmd;
                # The composed grep command must reference this case's
                # message (checked as a plain substring since _shell_quote
                # escapes the apostrophe in "Couldn't").
                return (index($cmd, $case->{needle}) >= 0) ? 0 : 1;
        });
        is(publiccloud::zypper::_handle_transient_failure($inst, 1, 1, 3, 'transactional'),
            'retry', "retries on $case->{label}");
    }
};

subtest '[_handle_transient_failure] transactional failure without lock message fails' => sub {
    my $inst = _instance_mock_positional();
    $inst->mock(ssh_script_run => sub { return 1 });    # grep finds nothing -> non-zero
    is(publiccloud::zypper::_handle_transient_failure($inst, 1, 1, 3, 'transactional'),
        'fail', 'does not retry a genuine transactional-update failure');
};

subtest '[_handle_transient_failure] zypper-kind checks unaffected by kind arg' => sub {
    my $testapi_mock = Test::MockModule->new('publiccloud::zypper');
    $testapi_mock->redefine(record_info => sub { return 1 });
    my $inst = _instance_mock(run_rc => 1);    # log grep misses
    is(publiccloud::zypper::_handle_transient_failure($inst, publiccloud::zypper::EXIT_LOCKED(), 1, 3),
        'retry', 'zypp lock still retried when kind defaults to zypper');
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

done_testing;
