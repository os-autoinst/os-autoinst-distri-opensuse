# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can scan audit logs
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#67933, tc#1741266, poo#103341

use base 'apparmortest';
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

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Enter "yast2 apparmor"
    enter_cmd("yast2 apparmor &");
    # Enter "Scan Audit logs" and check there should no records
    assert_and_click("AppArmor-Scan-Audit-logs", timeout => 120);
    assert_and_click("AppArmor-Launch", timeout => 60);
    wait_still_screen(5);
    if (!check_screen("AppArmor-Scan-Audit-logs-no-records")) {
        assert_and_click("AppArmor-Launch", timeout => 60);
        record_soft_failure("bsc#1190292, add workaround to click 'Launch' again");
    }
    assert_screen("AppArmor-Scan-Audit-logs-no-records");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-o" };

    # 2. Generate audit records for testing
    # Exit x11 and turn to console
    send_key "alt-f4";
    assert_screen("generic-desktop");
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;

    # Setup testing profile/auditlog
    # E.g., comment out specific entries from profile, then run corresponding programs to generate audit records
    assert_script_run("cp $test_profile $test_profile_bk");
    assert_script_run("sed -i -e 's/$entry/#$entry/' $test_profile");
    validate_script_output("grep '#' $test_profile", sub { m/#$entry/ });
    assert_script_run("$test_file");
    validate_script_output("grep 'DENIED' $audit_log", sub { m/type=AVC.*msg=audit.*apparmor=.*DENIED.*profile=.*nscd.*comm=.*nscd.*/ });

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Enter "yast2 apparmor" and verify apparmor can revise the profile based on former violation
    enter_cmd("yast2 apparmor &");
    # Enter "Scan Audit logs" and check there should have records
    assert_and_click("AppArmor-Scan-Audit-logs", timeout => 120);
    assert_and_click("AppArmor-Launch", timeout => 60);
    wait_still_screen(5);
    if (!check_screen("AppArmor-Scan-Audit-logs-scan-records")) {
        assert_and_click("AppArmor-Launch", timeout => 60);
        record_soft_failure("bsc#1190292, add workaround to click 'Launch' again");
    }
    assert_screen("AppArmor-Scan-Audit-logs-scan-records");

    # Audit the entry
    send_key "alt-u";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-audit", "tab", 2, 2);
    send_key "alt-u";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-scan-records", "tab", 2, 2);

    # Allow the entry
    send_key "alt-a";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-allow", "tab", 2, 2);

    # View changes
    send_key "alt-v";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-view-changes", "tab", 2, 2);
    send_key "alt-o";

    # View changes b/w clean profile
    send_key "alt-i";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-view-changes-clean-profile", "tab", 2, 2);
    send_key "alt-o";

    # Abort: no
    send_key "alt-a";
    send_key_until_needlematch("AppArmor-Scan-Audit-logs-abort", "tab", 2, 2);
    send_key "alt-n";
    assert_screen("AppArmor-Scan-Audit-logs-allow");

    # Save changes
    send_key "alt-s";
    assert_screen("AppArmor-Scan-Audit-logs-saved");
    send_key "alt-o";

    # Upload test profile for reference
    upload_logs($test_profile);

    # Yast2 AppArmor clean up
    assert_script_run("mv $test_profile_bk $test_profile");
    $self->yast2_apparmor_cleanup();
}

1;
