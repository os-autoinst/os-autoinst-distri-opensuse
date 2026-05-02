# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Zypper / transactional-update plumbing for public cloud tests.
#
# This module centralises all package-management interactions with remote
# public cloud instances (and a small helper for local installations).
#
# Public API:
#   - zypper_call($instance, $cmd, %opts)        plain "sudo zypper -n $cmd"
#   - transactional_call($instance, $cmd, %opts) "sudo transactional-update -n $cmd"
#   - pkg_call($instance, $cmd, %opts)           dispatches based on is_transactional()
#   - refresh($instance, %opts)                  "zypper ref" (always plain, even on
#                                                transactional systems -- poo#195920)
#   - add_repo($instance, $name, $url, %opts)
#   - wait_quit($instance, %opts)                wait for zypper/rpm/etc to finish
#   - installed_packages($instance, \@pkgs)      returns arrayref
#   - available_packages($instance, \@pkgs)      returns arrayref
#   - install_packages_local(\@pkgs, %opts)      local helper, branches on
#                                                is_transactional()
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::zypper;

use strict;
use warnings;
use base 'Exporter';

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
    EXIT_REBOOT_NEEDED => 102,
    EXIT_REBOOT_SCHED => 103,
    EXIT_CAP_NOT_FOUND => 104,    # ZYPPER_EXIT_INF_CAP_NOT_FOUND
    EXIT_RPM_SCRIPT_FAIL => 107,    # ZYPPER_EXIT_INF_RPM_SCRIPT_FAILED
};

our @EXPORT_OK = qw(
  zypper_call
  transactional_call
  pkg_call
  refresh
  add_repo
  wait_quit
  installed_packages
  available_packages
  install_packages_local
  EXIT_OK
  EXIT_SOLVER
  EXIT_NO_REPOS
  EXIT_LOCKED
  EXIT_REBOOT_NEEDED
  EXIT_REBOOT_SCHED
  EXIT_CAP_NOT_FOUND
  EXIT_RPM_SCRIPT_FAIL
);

our %EXPORT_TAGS = (
    all => [@EXPORT_OK],
    codes => [grep { /^EXIT_/ } @EXPORT_OK],
);

# Tunable defaults
use constant DEFAULT_TIMEOUT_ZYPPER => 700;
use constant DEFAULT_TIMEOUT_TRANSACTIONAL => 900;
use constant DEFAULT_RETRY => 1;
use constant DEFAULT_DELAY => 5;
use constant ZYPPER_LOG => '/var/log/zypper.log';

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

=head2 zypper_call

    zypper_call($instance, $cmd, %opts);
    zypper_call($instance, cmd => $cmd, %opts);

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

sub zypper_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);
    _validate_args($cmd, \%opts);
    my $full_cmd = "sudo zypper -n $cmd";
    return _run($instance, $full_cmd, %opts, _kind => 'zypper');
}

=head2 transactional_call

    transactional_call($instance, $cmd, %opts);

Runs C<sudo transactional-update -n $cmd> on a remote instance and triggers
a soft reboot on success (unless C<no_reboot => 1> is passed). The default
accepted exit codes are 0, 102, 103.

=cut

sub transactional_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);
    _validate_args($cmd, \%opts);

    $opts{timeout} //= DEFAULT_TIMEOUT_TRANSACTIONAL;
    $opts{exitcode} //= [EXIT_OK, EXIT_REBOOT_NEEDED, EXIT_REBOOT_SCHED];
    my $no_reboot = delete $opts{no_reboot};

    my $full_cmd = "sudo transactional-update -n $cmd";
    my $ret = _run($instance, $full_cmd, %opts, _kind => 'transactional');

    if (!$no_reboot && grep { $_ == $ret } @{$opts{exitcode}}) {
        $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    }
    return $ret;
}

=head2 pkg_call

    pkg_call($instance, $cmd, %opts);

Smart dispatch: on transactional systems, translates C<$cmd> into the
equivalent C<transactional-update> invocation when possible (for install /
remove / update / dup / patch). Anything that C<transactional-update> does
not support (refresh, repo management, queries, ...) falls through to plain
C<zypper_call>. On non-transactional systems this is identical to
C<zypper_call>.

=cut

sub pkg_call {
    my ($instance, $cmd, %opts) = _normalize_call_args(@_);

    if (is_transactional() && _is_translatable_to_transactional($cmd)) {
        my $tcmd = _zypper_to_transactional($cmd);
        return transactional_call($instance, $tcmd, %opts);
    }
    return zypper_call($instance, $cmd, %opts);
}

=head2 refresh

    refresh($instance, %opts);

Refreshes repositories on the remote instance. Always uses plain zypper,
even on transactional systems, because C<transactional-update> does not
support repo refresh actions (poo#195920).

=cut

sub refresh {
    my ($instance, %opts) = @_;
    $opts{retry} //= 3;
    $opts{delay} //= 60;
    $opts{timeout} //= 90;
    return zypper_call($instance, '--gpg-auto-import-keys ref', %opts);
}

=head2 add_repo

    add_repo($instance, $name, $url, [timeout => 600]);

Adds a GPG-checked repository to the remote instance. Uses
C<ssh_assert_script_run> directly (i.e. dies on non-zero exit) rather than
the full C<zypper_call> retry pipeline, since adding a single repository is
a one-shot operation.

=cut

sub add_repo {
    my ($instance, $name, $url, %opts) = @_;
    my $timeout = $opts{timeout} // 600;
    $instance->ssh_assert_script_run(
        cmd => "sudo zypper -n addrepo -fG $url $name",
        timeout => $timeout,
    );
}

=head2 wait_quit

    wait_quit($instance, [timeout => 20], [delay => 10], [retry => 120]);

Waits until no zypper / packagekit / purge-kernels / rpm processes are
running on the remote instance. Defaults give a ~20 minute ceiling.

=cut

sub wait_quit {
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

=head2 installed_packages

    installed_packages($instance, \@pkgs);

Returns an arrayref of those packages from C<\@pkgs> that are installed on
the remote instance, preserving the order from the input list.

=cut

sub installed_packages {
    my ($instance, $pkgs_ref) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';
    return [] unless @$pkgs_ref;

    my $pkg_list = join(' ', @$pkgs_ref);
    my $output = $instance->ssh_script_output(
        cmd => qq{rpm -q --qf '%{NAME}|' $pkg_list 2>/dev/null},
        proceed_on_failure => 1,
    );
    my %seen = map { $_ => 1 }
      grep { length && $_ !~ /is not installed/i }
      split(/\|/, $output);
    return [grep { $seen{$_} } @$pkgs_ref];
}

=head2 available_packages

    available_packages($instance, \@pkgs);

Returns an arrayref of packages from C<\@pkgs> that are not yet installed
but are available for installation. Uses C<zypper -x info> to query
availability.

=cut

sub available_packages {
    my ($instance, $pkgs_ref) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';

    my %installed = map { $_ => 1 } @{installed_packages($instance, $pkgs_ref)};
    my @missing = grep { !$installed{$_} } @$pkgs_ref;
    return [] unless @missing;

    my $output = $instance->ssh_script_output(
        cmd => 'zypper -x info ' . join(' ', @missing) . ' 2>/dev/null',
        proceed_on_failure => 1,
    );
    my %available = map { $_ => 1 } ($output =~ /^Name\s*:\s*(\S+)/mg);
    return [grep { $available{$_} } @missing];
}

=head2 install_packages_local

    install_packages_local(\@pkgs, [timeout => $seconds]);

Installs packages on the local SUT. On transactional systems uses
C<trup_call("pkg install ...")> followed by C<reboot_on_changes>; otherwise
uses the standard C<zypper_call("in ...")>.

=cut

sub install_packages_local {
    my ($pkgs_ref, %opts) = @_;
    die "Expected arrayref" unless ref($pkgs_ref) eq 'ARRAY';
    return unless @$pkgs_ref;

    my $list = join(' ', @$pkgs_ref);
    if (is_transactional()) {
        transactional::trup_call("pkg install $list");
        transactional::reboot_on_changes();
        return;
    }
    if (defined $opts{timeout}) {
        utils::zypper_call("in $list", timeout => $opts{timeout});
    } else {
        utils::zypper_call("in $list");
    }
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

    wait_quit($instance) if $wait_quit;

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
        sleep($delay) if defined $ret;
        $ret = $instance->ssh_script_run(cmd => $cmd, %$ssh_args);
        return $ret if $ret == EXIT_OK;

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
sub _is_translatable_to_transactional {
    my ($cmd) = @_;
    my $verb = _verb_of($cmd);
    return 0 unless defined $verb;
    return exists $TOPLEVEL_VERB{$verb} || exists $PKG_VERB{$verb};
}

# Translate a zypper-style $cmd into the equivalent transactional-update
# invocation. Dies if the verb is not supported.
sub _zypper_to_transactional {
    my ($cmd) = @_;

    my @parts = split(/\s+/, $cmd);
    my @flags;
    while (@parts && $parts[0] =~ /^-/) {
        push @flags, shift @parts;
    }
    my $verb = shift @parts;
    my @rest = @parts;

    die "Cannot translate empty zypper command to transactional-update" unless defined $verb;

    if (exists $TOPLEVEL_VERB{$verb}) {
        # bare "up" / "dup" / "patch" -> top-level command
        return join(' ', @flags, $TOPLEVEL_VERB{$verb}) unless @rest;

        # "up <pkgs>" -> "pkg update <pkgs>".  dup/patch don't accept package
        # arguments at the top level, so route them through `pkg` only when
        # supported (only `update` is, per the man page).
        if ($verb eq 'up' || $verb eq 'update') {
            return join(' ', @flags, 'pkg', 'update', @rest);
        }
        die "transactional-update does not support '$verb' with package arguments";
    }
    if (exists $PKG_VERB{$verb}) {
        return join(' ', @flags, 'pkg', $PKG_VERB{$verb}, @rest);
    }

    die "Cannot translate zypper command '$cmd' to transactional-update: "
      . "verb '$verb' is not supported by transactional-update. "
      . "Use zypper_call() explicitly if this command is intended to bypass "
      . "transactional-update.";
}

sub _verb_of {
    my ($cmd) = @_;
    my @parts = split(/\s+/, $cmd);
    shift @parts while @parts && $parts[0] =~ /^-/;
    return $parts[0];
}

1;
