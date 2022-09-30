# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can scan audit logs
# Maintainer: QE Security <none@suse.de>
# Tags: poo#67933, tc#1741266, poo#103341

use base 'apparmortest';
use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = shift;
    my $test_file = "/usr/sbin/nscd";
    my $test_profile = "/etc/apparmor.d/usr.sbin.nscd";
    my $test_profile_bk = "/tmp/usr.sbin.nscd";
    my $entry = 'include <abstractions\/base>';
    my $audit_log = $apparmortest::audit_log;

    # Set the testing profile to "enforce" mode
    assert_script_run("aa-enforce $test_file");

    # 1. Clear audit records for testing
    assert_script_run("echo '' > $audit_log");

    systemctl("start apparmor");
    systemctl("is-active apparmor");

    # Enter "yast2 apparmor"
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
    assert_screen("yast2_apparmor");

    # Enter "Scan Audit logs" and check there should no records
    wait_screen_change { send_key "down" };
    send_key("ret");
    assert_screen("yast2_apparmor-scanlogs-no-records");
    wait_screen_change { send_key "alt-o" };

    # Wait till app is closed
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    enter_cmd("reset");

    # 2. Generate audit records for testing
    # Setup testing profile/auditlog
    # E.g., comment out specific entries from profile, then run corresponding programs to generate audit records
    assert_script_run("cp $test_profile $test_profile_bk");
    assert_script_run("sed -i -e 's/$entry/#$entry/' $test_profile");
    validate_script_output("grep '#' $test_profile", sub { m/#$entry/ });
    assert_script_run("$test_file");
    validate_script_output("grep 'DENIED' $audit_log", sub { m/type=AVC.*msg=audit.*apparmor=.*DENIED.*profile=.*nscd.*comm=.*nscd.*/ });

    # Enter "yast2 apparmor" and verify apparmor can revise the profile based on former violation
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
    assert_screen("yast2_apparmor");
    # Enter "Scan Audit logs" and check there should have records
    wait_screen_change { send_key "down" };
    send_key("ret");
    assert_screen("yast2_apparmor-scanlogs-have-records");

    # Audit the entry
    send_key "alt-u";
    assert_screen("yast2_apparmor-audit_cap_kill");
    wait_screen_change { send_key "alt-u" };

    # Allow the entry
    wait_screen_change { send_key "alt-a" };
    assert_screen("yast2_apparmor-save_changed_profile");

    # View changes
    wait_screen_change { send_key "alt-v" };
    save_screenshot;
    wait_screen_change { send_key "alt-o" };

    # View changes b/w clean profile
    wait_screen_change { send_key "alt-i" };
    save_screenshot;
    wait_screen_change { send_key "alt-o" };

    # Abort: no
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "alt-n" };
    assert_screen("yast2_apparmor-save_changed_profile");

    # Save changes
    wait_screen_change { send_key "alt-s" };
    assert_screen("yast2_apparmor-scanlogs-no-records");
    send_key "alt-o";

    # Wait till app is closed
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    enter_cmd("reset");

    # Upload test profile for reference
    upload_logs($test_profile);

    # Yast2 AppArmor clean up
    assert_script_run("mv $test_profile_bk $test_profile");
    upload_logs($apparmortest::audit_log);
}

1;
