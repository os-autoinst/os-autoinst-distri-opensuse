# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test execution of the run0 binary
# Maintainer: QE Security <none@suse.de>
# Tags: poo#160322

use base 'consoletest';
use testapi;

sub run {
    select_console('root-console');
    my $systemd_version = script_output("rpm -q --qf \%{VERSION} systemd | cut -d. -f1");
    # run0 unavailable on systemd versions < 256
    if ($systemd_version lt 256) {
        record_info(
            'SKIPPED',
            "run0 requires systemd >= 256 (found $systemd_version)"
        );
        return;
    }
    assert_script_run('command -v run0');
    assert_script_run('run0 true');
    my $uid = script_output('run0 id -u');
    die "run0 did not run as root (uid=$uid)" unless $uid eq '0';
}

1;
