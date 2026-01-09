# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test execution of the run0 binary
# Maintainer: QE Security <none@suse.de>
# Tags: poo#160322, poo#194417

use base 'consoletest';
use testapi;

sub run {
    select_serial_terminal;
    # run0 unavailable on systemd versions < 256
    my $systemd_version = script_output("rpm -q --qf \%{VERSION} systemd | cut -d. -f1");
    if ($systemd_version lt 256) {
        record_info(
            'SKIPPED',
            "run0 requires systemd >= 256 (found $systemd_version)"
        );
        return;
    }
    # Basic execution
    assert_script_run('command -v run0');
    assert_script_run('run0 true');
    my $uid = script_output('run0 id -u');
    die "run0 did not run as root (uid=$uid)" unless $uid eq '0';
    # User change
    my $uid = script_output('run0 --user=bernhard id -u');
    die "run0 did not run with specific user (uid=$uid)" unless $uid eq '1000';
    # Exit and error handling
    my $rc = script_run('run0 false');
    die "run0 swallowed non-zero exit code" if $rc == 0;
    my $missing_rc = script_run('run0 does-not-exist');
    die "run0 succeeded with non-existent command" if $missing_rc == 0;
    # Environment handling
    my $env = script_output(q{FOO=bar run0 env});
    die "Untrusted environment variable leaked into run0" if $env =~ m{^FOO=bar$}m;
    my $path = script_output('run0 sh -c "echo $PATH"');
    die "PATH missing /usr/bin" unless $path =~ m{/usr/bin};
    # Non-interactive
    assert_script_run('script -q -c "run0 true" /dev/null');
}

1;
