# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can manually add profile,
#          also verify Bug 1172040 - YaST2 apparmor profile creation:
#          "View profile" does nothing
# Maintainer: QE Security <none@suse.de> (Slack channel: #discuss-qe-security)
# Tags: poo#70537, tc#1741266, poo#103341

use base 'apparmortest';
use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $test_file = "cat";
    my $test_profile = "/etc/apparmor.d/usr.bin.cat";
    my $test_file_bk = "cat_bk";
    my $test_profile_bk = "/etc/apparmor.d/usr.bin.cat_bk";
    my $test_file_vsftpd = "vsftpd";
    my $test_profile_vsftpd = "/etc/apparmor.d/usr.sbin.vsftpd";

    # Setup testing files
    assert_script_run("rm -f $test_profile");
    assert_script_run("rm -f $test_profile_bk");
    assert_script_run("rm -f $test_profile_vsftpd");
    assert_script_run("cp /usr/bin/$test_file /usr/bin/$test_file_bk");
    zypper_call("in vsftpd");

    systemctl("start apparmor");
    systemctl("is-active apparmor");

    # Enter "Manually Add Profile" to generate a profile for a program
    # "marked as a program that should not have its own profile",
    # it should be failed
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
    assert_screen("yast2_apparmor");
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    send_key("ret");
    assert_screen("yast2_apparmor_configuration_add_profile");
    wait_screen_change { send_key "alt-f" };
    # Delete the filename that's already written and type our filename
    for (1 .. 10) { send_key "backspace"; }
    type_string("$test_file");
    send_key("alt-o");
    assert_screen("yast2_apparmor_profile-generation-error");
    send_key("alt-o");
    # Wait till app is closed
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    enter_cmd("reset");

    # Enter "Manually Add Profile" to generate a profile for a program
    # *NOT* "marked as a program that should not have its own profile",
    # it should be succeeded
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => "apparmor");
    assert_screen("yast2_apparmor");
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    send_key("ret");
    assert_screen("yast2_apparmor_configuration_add_profile");
    wait_screen_change { send_key "alt-f" };
    # Delete the filename that's already written and type our filename
    for (1 .. 10) { send_key "backspace"; }
    type_string("$test_file_bk");
    send_key("alt-o");
    assert_screen("yast2_apparmor_scan-system-log");
    # Scan system
    send_key "alt-s";
    assert_screen("yast2_apparmor_scan-system-log");
    # Generate profile
    send_key "alt-f";
    assert_screen("yast2_apparmor_profile-generated-ok");
    send_key("alt-o");
    # Wait till app is closed
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    enter_cmd("reset");

    # Verify bsc#1172040
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => "apparmor");
    assert_screen("yast2_apparmor");
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "down" };
    send_key("ret");
    assert_screen("yast2_apparmor_configuration_add_profile");
    # Select /usr/sbin directory
    send_key("ret");
    wait_still_screen(2);
    wait_screen_change { send_key "ret" };
    send_key_until_needlematch("yast2_apparmor-change-dir-to-sbin", "down", 7, 2);
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-f" };
    # Delete the filename that's already written and type our filename
    for (1 .. 12) { send_key "backspace"; }
    type_string("$test_file_vsftpd");
    send_key("alt-o");
    assert_screen("yast2_apparmor_inactive-profile");
    # Check "View Profile"
    send_key("alt-v");
    assert_screen("yast2_apparmor_view-profile");
    wait_screen_change { send_key "alt-o" };
    # Check "Use Profile"
    send_key("alt-u");
    assert_screen("yast2_apparmor_scan-system-log");
    send_key("alt-f");
    assert_screen("yast2_apparmor_profile-generated");
    send_key("alt-o");
    # Wait till app is closed
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    enter_cmd("reset");

    # Check the profiles were generated, e.g., cat it for reference
    assert_script_run("cat $test_profile_bk");
    assert_script_run("cat $test_profile_vsftpd");

    # Clean up
    assert_script_run("rm -f /usr/bin/$test_file_bk");
    assert_script_run("rm -f $test_profile_bk");
    assert_script_run("rm -f $test_profile_vsftpd");
}

1;
