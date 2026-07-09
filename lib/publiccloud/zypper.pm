# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
#
# Summary: Zypper / transactional-update plumbing for public cloud tests
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::zypper;

=encoding UTF-8

=head1 NAME

publiccloud::zypper - Zypper / transactional-update plumbing for public cloud tests

=head1 SYNOPSIS

    use publiccloud::zypper qw(pc_pkg_call pc_refresh pc_add_repo);

    pc_refresh($instance);
    pc_add_repo($instance, 'my-repo', 'http://example.com/repo');
    pc_pkg_call($instance, 'in some-package');

=head1 DESCRIPTION

Centralises all package-management interactions with remote public cloud
instances (and a small helper for local installations). On transactional
systems, package-changing operations are transparently routed through
C<transactional-update>; refresh and repository management always go
through plain C<zypper>.

=head1 PUBLIC API

=over 4

=item L</pc_zypper_call>           - plain C<sudo zypper -n ...>

=item L</pc_transactional_call>    - plain C<sudo transactional-update -n ...>

=item L</pc_pkg_call>              - smart dispatch based on C<is_transactional()>

=item L</pc_refresh>               - C<zypper ref> (always plain; poo#195920)

=item L</pc_add_repo>              - add a GPG-checked repository

=item L</pc_wait_quit>             - wait for zypper/rpm/etc. to finish

=item L</pc_installed_packages>    - filter list to installed packages

=item L</pc_available_packages>    - filter list to available-but-not-installed

=item L</pc_install_packages_local> - local-SUT install helper

=back

See the per-function sections below for full signatures and options.

=cut

use strict;
use warnings;
use Exporter qw(import);

use testapi;
use utils ();
use transactional ();
use version_utils qw(is_transactional);

# Zypper exit codes (see man zypper, EXIT CODES section)
use constant {
    EXIT_OK => 0,
    EXIT_SOLVER => 4,    # generic solver problem
    EXIT_NO_REPOS => 6,    # ZYPPER_EXIT_NO_REPOS
    EXIT_LOCKED => 7,    # ZYPPER_EXIT_ZYPP_LOCKED
    EXIT_ERR_COMMIT => 8,    # ZYPPER_EXIT_ERR_COMMIT (commit error; can be caused by a lock held at transaction time)
    EXIT_REBOOT_NEEDED => 102,
    EXIT_REBOOT_SCHED => 103,
    EXIT_CAP_NOT_FOUND => 104,    # ZYPPER_EXIT_INF_CAP_NOT_FOUND
    EXIT_RPM_SCRIPT_FAIL => 107,    # ZYPPER_EXIT_INF_RPM_SCRIPT_FAILED
                                    # Tunable defaults
    DEFAULT_TIMEOUT_ZYPPER => 700,
    DEFAULT_TIMEOUT_TRANSACTIONAL => 900,
    DEFAULT_RETRY => 1,
    DEFAULT_DELAY => 5,
    ZYPPER_LOG => '/var/log/zypper.log',
};

our @EXPORT_OK = qw(
  pc_zypper_call
  pc_transactional_call
  pc_pkg_call
  pc_refresh
  pc_add_repo
  pc_wait_quit
  pc_installed_packages
  pc_available_packages
  pc_install_packages_local
  EXIT_OK
  EXIT_SOLVER
  EXIT_NO_REPOS
  EXIT_LOCKED
  EXIT_ERR_COMMIT
  EXIT_REBOOT_NEEDED
  EXIT_REBOOT_SCHED
  EXIT_CAP_NOT_FOUND
  EXIT_RPM_SCRIPT_FAIL
);

our %EXPORT_TAGS = (
    all => [@EXPORT_OK],
    codes => [grep { /^EXIT_/ } @EXPORT_OK],
);


# Strict allow-list of zypper verbs that transactional-update can wrap.
# See https://kubic.opensuse.org/documentation/man-pages/transactional-update.8.html
#
# Top-level transactional-update commands (no `pkg` prefix). Note `up`/`update`
# at the toplevel updates the whole system; `pkg update <pkgs>` updates a
# selection.
my %TOPLEVEL_VERB = (
    up => 'up',
    update => 'up',
    dup => 'dup',
    'dist-upgrade' => 'dup',
    patch => 'patch',
);

# Verbs that require the `pkg <verb>` wrapper.
my %PKG_VERB = (
    in => 'install',
    install => 'install',
    rm => 'remove',
    remove => 'remove',
);

# The *only* options transactional-update accepts in its global slot, i.e.
# before the general/package command (see OPTIONS in transactional-update.8).
# Any other dash-prefixed token is a zypper *command* option and must travel
# with the verb, never be hoisted here -- otherwise e.g. `zypper in -y curl`
# would become `transactional-update -y pkg install curl`, and `-y` is not a
# valid transactional-update global option.
my %TU_GLOBAL_OPT = map { $_ => 1 } qw(
  -i --interactive
  -n --non-interactive
  -c --continue
  -d --drop-if-no-change
  --quiet
  --no-selfupdate
  --no-allow-vendor-change
);

# Failure-classification table. Maps zypper exit codes to a label and a
# regex used to scrape the relevant lines from the last zypper session in
# /var/log/zypper.log.
my %FAILURE_CLASSIFIERS = (
    EXIT_CAP_NOT_FOUND() => {
        label => 'ZYPPER_EXIT_INF_CAP_NOT_FOUND',
        regex => '(SolverRequester.cc|THROW|CAUGHT)',
    },
    EXIT_RPM_SCRIPT_FAIL() => {
        label => 'ZYPPER_EXIT_INF_RPM_SCRIPT_FAILED',
        regex => 'RpmPostTransCollector\.cc\(executeScripts\):.* scriptlet failed, exit status',
    },
);

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

=head2 pc_zypper_call

    pc_zypper_call($instance, $cmd, %opts);
    pc_zypper_call($instance, cmd => $cmd, %opts);

Runs C<sudo zypper -n $cmd> on a remote instance. Never wraps the command in
C<transactional-update>; use this for repo/refresh/info operations even on
transactional systems.

Options (all optional):

=over 4

=item B<timeout>           => seconds, default 700

=item B<retry>             => number of attempts, default 1

=item B<delay>             => seconds between retries, default 5

=item B<exitcode>          => arrayref of accepted exit codes, default [0]

=item B<proceed_on_failure> => if true, record the failure but don't die

=item B<wait_quit>          => if true (default), wait for any running
                                zypper-related processes to finish before
                                running the command

=back

=cut

sub pc_zypper_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);
    _validate_args($cmd, \%opts);
    return _run($instance, "sudo zypper -n $cmd", %opts, _kind => 'zypper');
}

=head2 pc_transactional_call

    pc_transactional_call($instance, $cmd, %opts);

Runs C<sudo transactional-update -n $cmd> on a remote instance and triggers
a soft reboot on success (unless C<no_reboot => 1> is passed). The default
accepted exit codes are 0, 102, 103.

=cut

sub pc_transactional_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);
    _validate_args($cmd, \%opts);

    $opts{timeout} //= DEFAULT_TIMEOUT_TRANSACTIONAL;
    $opts{exitcode} //= [EXIT_OK, EXIT_REBOOT_NEEDED, EXIT_REBOOT_SCHED];
    my $no_reboot = delete $opts{no_reboot};

    my $ret = _run($instance, "sudo transactional-update -n $cmd", %opts, _kind => 'transactional');

    if (!$no_reboot && grep { $_ == $ret } @{$opts{exitcode}}) {
        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    }
    return $ret;
}

=head2 pc_pkg_call

    pc_pkg_call($instance, $cmd, %opts);

Smart dispatch: on transactional systems, translates C<$cmd> into the
equivalent C<transactional-update> invocation when possible (for install /
remove / update / dup / patch). Anything that C<transactional-update> does
not support (refresh, repo management, queries, ...) falls through to plain
C<pc_zypper_call>. On non-transactional systems this is identical to
C<pc_zypper_call>.

=cut

sub pc_pkg_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);

    return pc_transactional_call($instance, _zypper_to_transactional($cmd), %opts)
      if (is_transactional() && _is_translatable_to_transactional($cmd));

    return pc_zypper_call($instance, $cmd, %opts);
}

=head2 pc_refresh

    pc_refresh($instance, %opts);

Refreshes repositories on the remote instance. Always uses plain zypper,
even on transactional systems, because C<transactional-update> does not
support repo refresh actions (poo#195920).

=cut

sub pc_refresh {
    my ($instance, %opts) = @_;
    $opts{retry} //= 3;
    $opts{delay} //= 60;
    $opts{timeout} //= 90;
    return pc_zypper_call($instance, '--gpg-auto-import-keys ref', %opts);
}

=head2 pc_add_repo

    pc_add_repo($instance, $name, $url, [timeout => 600]);

Adds a GPG-checked repository to the remote instance. Uses
C<ssh_assert_script_run> directly (i.e. dies on non-zero exit) rather than
the full C<pc_zypper_call> retry pipeline, since adding a single repository is
a one-shot operation.

=cut

sub pc_add_repo {
    my ($instance, $name, $url, %opts) = @_;
    my $timeout = $opts{timeout} // 600;
    $instance->ssh_assert_script_run(
        cmd => "sudo zypper -n addrepo -fG $url $name",
        timeout => $timeout,
    );
}

=head2 pc_wait_quit

    pc_wait_quit($instance, [timeout => 20], [delay => 10], [retry => 120]);

Waits until no zypper / packagekit / purge-kernels / rpm processes are
running on the remote instance. Defaults give a ~20 minute ceiling.

=cut

sub pc_wait_quit {
    my ($instance, %opts) = @_;
    my $timeout = $opts{timeout} // 20;
    my $delay = $opts{delay} // 10;
    my $retry = $opts{retry} // 120;

    # RC 0 (success) only when no matching processes exist.
    my $cmd = q{! pgrep -a "zypper|packagekit|purge-kernels|rpm"};

    $instance->ssh_script_retry(
        cmd => $cmd,
        timeout => $timeout,
        delay => $delay,
        retry => $retry,
    );
}

=head2 pc_installed_packages

    pc_installed_packages($instance, \@pkgs);

Returns an arrayref of those packages from C<\@pkgs> that are installed on
the remote instance, preserving the order from the input list.

=cut

sub pc_installed_packages {
    my ($instance, $pkgs_ref) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';
    return [] unless @$pkgs_ref;

    my $pkg_list = join(' ', @$pkgs_ref);
    my $output = $instance->ssh_script_output(
        cmd => qq{rpm -q --qf '%{NAME}|' $pkg_list 2>/dev/null},
        proceed_on_failure => 1,
    );
    my @seen = grep { length && $_ !~ /is not installed/i } split(/\|/, $output);
    return \@seen;
}

=head2 pc_available_packages

    pc_available_packages($instance, \@pkgs);

Returns an arrayref of packages from C<\@pkgs> that are not yet installed
but are available for installation. Uses C<zypper -x info> to query
availability.

=cut

sub pc_available_packages {
    my ($instance, $pkgs_ref) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';

    my %installed = map { $_ => 1 } @{pc_installed_packages($instance, $pkgs_ref)};
    my @missing = grep { !$installed{$_} } @$pkgs_ref;
    return [] unless @missing;

    my $output = $instance->ssh_script_output(
        cmd => 'zypper -x info ' . join(' ', @missing) . ' 2>/dev/null',
        proceed_on_failure => 1,
    );
    my @available = ($output =~ /^Name\s*:\s*(\S+)/mg);
    return \@available;
}

=head2 pc_install_packages_local

    pc_install_packages_local(\@pkgs, [timeout => $seconds]);

Installs packages on the local SUT. On transactional systems uses
C<trup_call("pkg install ...")> followed by C<reboot_on_changes>; otherwise
uses the standard C<utils::zypper_call("in ...")>.

=cut

sub pc_install_packages_local {
    my ($pkgs_ref, %opts) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';
    return unless @$pkgs_ref;

    my $list = join(' ', @$pkgs_ref);
    if (is_transactional()) {
        transactional::trup_call("pkg install $list");
        transactional::reboot_on_changes();
        return;
    }
    utils::zypper_call("in $list", timeout => $opts{timeout} // $bmwqemu::default_timeout);    # avoid "package not found" errors due to stale cache
    return;
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Accept any of:
#   func($instance, "cmd", retry => 3)             positional cmd
#   func($instance, cmd => "cmd", retry => 3)      named cmd
#   $instance->func("cmd", retry => 3)             method-style positional
#   $instance->func(cmd => "cmd")                  method-style named
sub _normalize_call_args {
    my $instance = shift;
    my $cmd;
    if (@_ && @_ % 2 == 1) {
        # odd number of remaining args -> first must be the positional cmd
        $cmd = shift;
    } elsif (@_ && (@_ % 2 == 0)) {
        # even -> could be (cmd => "...", ...) or (key => val, key => val)
        # without a leading positional.
        my %tmp = @_;
        if (exists $tmp{cmd}) {
            $cmd = delete $tmp{cmd};
            @_ = %tmp;
        } else {
            # No cmd provided; let _validate_args complain.
            $cmd = undef;
        }
    }
    return ($instance, $cmd, @_);
}

sub _validate_args {
    my ($cmd, $opts) = @_;
    die "Empty 'cmd' argument in zypper call" unless defined $cmd && length $cmd;
    die "Invalid value 'timeout' = 0" if exists $opts->{timeout} && defined $opts->{timeout} && !$opts->{timeout};
    die "Exit code is from PIPESTATUS[0], not grep" if $cmd =~ /^((?!`).)*\| ?grep/;
}

# Orchestrator. Owns argument cleanup, transient-failure handling,
# log uploads and reporting.
sub _run {
    my ($instance, $full_cmd, %opts) = @_;

    # Copy and consume our own options; everything else is passed through
    # to ssh_script_run.
    my %args = %opts;
    my $kind = delete $args{_kind};
    my $exit_codes = delete $args{exitcode} // [EXIT_OK];
    my $retry = delete $args{retry} // DEFAULT_RETRY;
    my $delay = delete $args{delay} // DEFAULT_DELAY;
    my $proceed = delete $args{proceed_on_failure} // 0;
    my $wait_quit = delete $args{wait_quit} // 1;
    $args{timeout} //= ($kind eq 'transactional')
      ? DEFAULT_TIMEOUT_TRANSACTIONAL
      : DEFAULT_TIMEOUT_ZYPPER;
    $args{rc_only} = 1;

    pc_wait_quit($instance) if $wait_quit;

    my $ret = _retry_loop($instance, $full_cmd, $retry, $delay, \%args);

    unless (grep { $_ == $ret } @$exit_codes) {
        _report_failure($instance, $full_cmd, $ret, $proceed);
    }
    record_info('zypper remote call', "Command: $full_cmd\nResult: $ret");
    return $ret;
}

sub _retry_loop {
    my ($instance, $cmd, $retry, $delay, $ssh_args) = @_;
    my $ret;
    for my $attempt (1 .. $retry) {
        $ret = $instance->ssh_script_run(cmd => $cmd, %$ssh_args);
        return $ret if $ret == EXIT_OK;
        sleep($delay) if defined $ret;

        my $action = _handle_transient_failure($instance, $ret, $attempt, $retry);
        return $ret if $action eq 'stop';
        next if $action eq 'retry';
        last;    # 'fail'
    }
    return $ret;
}

# Returns 'retry' (try again), 'stop' (give up but don't drop into the
# generic failure path), or 'fail' (let _run handle it).
sub _handle_transient_failure {
    my ($instance, $ret, $attempt, $max) = @_;

    if ($ret == EXIT_SOLVER) {
        # bsc#1070851 -- transient 502 from server; zypper should retry
        # internally. If we still see this, the bug-fix is missing.
        if (_log_grep($instance, 'Error code.*502') == 0) {
            die 'According to bsc#1070851 zypper should automatically retry internally. Bugfix missing for current product?';
        }
        if (_log_grep($instance, 'Solverrun finished with an ERROR') == 0) {
            my $awk = q{awk '/Solverrun finished with an ERROR/,/statistics/{ print group"|", $0; if ($0 ~ /statistics/ ){ print "EOL"; group++ } }' } . ZYPPER_LOG;
            my $conflicts = $instance->ssh_script_output("sudo $awk");
            record_info('Conflicts', $conflicts, result => 'fail');
            diag 'Package conflicts found, not retrying anymore' if $conflicts;
            return 'stop';
        }
        return 'retry';
    }
    if ($ret == EXIT_LOCKED) {
        record_info("Retry $attempt/$max as system management is locked");
        return 'retry';
    }
    # EXIT_ERR_COMMIT (8) can be caused by the zypp lock being held at
    # transaction time (the lock is taken later than the PID check done by
    # pc_wait_quit, so pgrep passes while the lock file is still present).
    # Only retry when the log confirms the root cause is a lock; otherwise
    # treat it as a genuine commit failure.
    if ($ret == EXIT_ERR_COMMIT) {
        if (_log_grep($instance, 'System management is locked') == 0) {
            record_info("Retry $attempt/$max as commit failed due to zypp lock");
            return 'retry';
        }
        return 'fail';
    }
    return 'fail';
}

sub _report_failure {
    my ($instance, $cmd, $ret, $proceed) = @_;

    $instance->ssh_script_run('sudo chmod o+r ' . ZYPPER_LOG);
    $instance->upload_log(ZYPPER_LOG);

    my $info = _classify_failure($instance, $ret);
    my $msg = "$cmd failed with code: $ret";
    if (defined $info->{label}) {
        $msg .= " ($info->{label})";
    }
    $msg .= "\n\nRelated zypper logs:\n" . ($info->{excerpt} // '');

    die $msg unless $proceed;
    record_info('zypper error', $msg, result => 'fail');
}

sub _classify_failure {
    my ($instance, $ret) = @_;
    my $cls = $FAILURE_CLASSIFIERS{$ret} // {label => undef, regex => 'Exception\.cc'};
    my $excerpt = _last_zypper_session($instance, $cls->{regex});
    return {label => $cls->{label}, excerpt => $excerpt};
}

# Extract the lines from the last "Hi, me zypper" session that match
# $regex. Replaces three near-identical inline pipelines.
sub _last_zypper_session {
    my ($instance, $regex) = @_;
    my $tmp = '/tmp/zlog_' . int(rand(1 << 31)) . '.txt';
    my $log = ZYPPER_LOG;
    $instance->ssh_script_run(
        sprintf(
            q{sudo tac %s | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep -E %s > %s},
            $log, _shell_quote($regex), $tmp
        )
    );
    return $instance->ssh_script_output("cat $tmp");
}

sub _log_grep {
    my ($instance, $pattern) = @_;
    return $instance->ssh_script_run(
        sprintf('sudo grep %s %s', _shell_quote($pattern), ZYPPER_LOG)
    );
}

sub _shell_quote {
    my ($s) = @_;
    $s =~ s/'/'\\''/g;
    return "'$s'";
}

# Returns true if $cmd's verb is something transactional-update can wrap.
# Only the verb decides translatability; option placement does not. Any zypper
# command option (whether before or after the verb) is carried with the verb by
# _zypper_to_transactional, so leading options never affect this check.
sub _is_translatable_to_transactional {
    my ($cmd) = @_;
    my $verb = _verb_of($cmd);
    return 0 unless defined $verb;
    return exists $TOPLEVEL_VERB{$verb} || exists $PKG_VERB{$verb};
}

# Translate a zypper-style $cmd into the equivalent transactional-update
# invocation. Dies if the verb is not supported.
#
# Token routing (per transactional-update.8):
#   - Only options in %TU_GLOBAL_OPT that appear *before* the verb are hoisted
#     into transactional-update's global slot (@globals).
#   - The verb and *everything from the verb onward* (its own flags and the
#     package arguments) stay together, verbatim and in order (@args). The man
#     page states `pkg <command> <arguments>` forwards any zypper option for
#     that command, so command flags must not be reordered or hoisted.
#   - A dash-prefixed token that precedes the verb but is *not* a recognised
#     global option is a zypper command flag in an unusual position; it is kept
#     with the verb's arguments (never silently dropped, never hoisted).
sub _zypper_to_transactional {
    my ($cmd) = @_;

    my @parts = grep { length } split(/\s+/, $cmd);
    my @globals;
    # Consume leading tokens until the verb. Recognised globals go to @globals;
    # any other leading flag is held back to be re-attached after the verb.
    my @pre_verb_flags;
    while (@parts && $parts[0] =~ /^-/) {
        my $tok = shift @parts;
        if ($TU_GLOBAL_OPT{$tok}) {
            push @globals, $tok;
        }
        else {
            push @pre_verb_flags, $tok;
        }
    }
    my $verb = shift @parts;
    # verb's arguments = any misplaced pre-verb command flags, then the rest.
    my @args = (@pre_verb_flags, @parts);

    die 'Cannot translate empty zypper command to transactional-update' unless defined $verb;

    if (exists $TOPLEVEL_VERB{$verb}) {
        # bare "up" / "dup" / "patch" -> top-level command
        return join(' ', @globals, $TOPLEVEL_VERB{$verb}) unless @args;

        # "up <pkgs>" -> "pkg update <pkgs>".  dup/patch don't accept package
        # arguments at the top level, so route them through `pkg` only when
        # supported (only `update` is, per the man page).
        if ($verb eq 'up' || $verb eq 'update') {
            return join(' ', @globals, 'pkg', 'update', @args);
        }
        die "transactional-update does not support '$verb' with package arguments";
    }
    if (exists $PKG_VERB{$verb}) {
        return join(' ', @globals, 'pkg', $PKG_VERB{$verb}, @args);
    }

    die "Cannot translate zypper command '$cmd' to transactional-update: "
      . "verb '$verb' is not supported by transactional-update. "
      . 'Use pc_zypper_call() explicitly if this command is intended to bypass '
      . 'transactional-update.';
}

sub _verb_of {
    my ($cmd) = @_;
    my @parts = split(/\s+/, $cmd);
    shift @parts while @parts && $parts[0] =~ /^-/;
    return $parts[0];
}

1;
