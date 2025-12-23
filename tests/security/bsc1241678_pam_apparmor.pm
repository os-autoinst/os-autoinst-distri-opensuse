# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test that the pam/apparmor updates fix the lockout issue
# Maintainer: QE Security <none@suse.de>
# Tag: bsc#1241678, poo#193627

use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    my $user = $testapi::username;

    select_serial_terminal;
    ensure_serialdev_permissions;

    assert_script_run('chmod 000 /etc/shadow');

    my $pam_old_version = '1.3.0-150000.6.76.1';
    my $apparmor_old_version = '3.1.7-150600.5.3.2';

    zypper_call(
        "in --oldpackage pam=$pam_old_version " .
          "apparmor-profiles=$apparmor_old_version " .
          "apparmor-abstractions=$apparmor_old_version " .
          "apparmor-docs=$apparmor_old_version " .
          "apparmor-parser=$apparmor_old_version " .
          "apparmor-parser-lang=$apparmor_old_version " .
          "apparmor-utils=$apparmor_old_version " .
          "apparmor-utils-lang=$apparmor_old_version " .
          "libapparmor1=$apparmor_old_version " .
          "python3-apparmor=$apparmor_old_version"
    );

    # Reproduce https://bugzilla.suse.com/show_bug.cgi?id=1241678
    die 'SSH should fail with old pam/apparmor' if script_run("ssh -o StrictHostKeyChecking=no $user\@localhost true", timeout => 10) == 0;
    record_info("Couldn't ssh into the system, bug REPRODUCED.");

    # Apply fixes
    zypper_call('up');

    # Verify fix
    assert_script_run("ssh -o StrictHostKeyChecking=no $user\@localhost true", timeout => 10);
    record_info("Could ssh into the system, bug is FIXED.");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
