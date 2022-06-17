# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can manually add profile,
#          also verify Bug 1172040 - YaST2 apparmor profile creation:
#          "View profile" does nothing
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#70537, tc#1741266, poo#103341

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $test_file = "/usr/bin/cat";
    my $test_profile = "/etc/apparmor.d/usr.bin.cat";
    my $test_file_bk = "/usr/bin/cat_bk";
    my $test_profile_bk = "/etc/apparmor.d/usr.bin.cat_bk";
    my $test_file_vsftpd = "/usr/sbin/vsftpd";
    my $test_profile_vsftpd = "/etc/apparmor.d/usr.sbin.vsftpd";

    # Setup testing files
    assert_script_run("rm -f $test_profile");
    assert_script_run("rm -f $test_profile_bk");
    assert_script_run("rm -f $test_profile_vsftpd");
    assert_script_run("cp $test_file $test_file_bk");
    zypper_call("in vsftpd");

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Enter "yast2 apparmor"
    enter_cmd("yast2 apparmor &");

    # Enter "Manually Add Profile" to generate a profile for a program
    # "marked as a program that should not have its own profile",
    # it should be failed
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 90);
    assert_and_click("AppArmor-Launch", timeout => 60);
    send_key_until_needlematch("AppArmor-Chose-a-program-to-generate-a-profile", "alt-n", 30, 3);
    type_string("$test_file");
    assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
    wait_still_screen(5);
    if (!check_screen("AppArmor-generate-a-profile-Error")) {
        assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
        record_soft_failure("bsc#1190295, add workaround to click 'Open' again");
        send_key "tab";
    }
    assert_screen("AppArmor-generate-a-profile-Error");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-o" };

    # Enter "yast2 apparmor" again
    enter_cmd("yast2 apparmor &");

    # Enter "Manually Add Profile" to generate a profile for a program
    # *NOT* "marked as a program that should not have its own profile",
    # it should be succeeded
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 60);
    assert_and_click("AppArmor-Launch", timeout => 60);
    assert_screen("AppArmor-Chose-a-program-to-generate-a-profile");
    type_string("$test_file_bk");
    assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
    wait_still_screen(5);
    if (!check_screen("AppArmor-Scan-system-log")) {
        assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
        record_soft_failure("bsc#1190295, add workaround to click 'Open' again");
        send_key "tab";
    }

    send_key_until_needlematch("AppArmor-Scan-system-log", "tab", 2, 2);
    # Scan systemlog
    send_key "alt-s";
    assert_screen("AppArmor-Scan-system-log");
    # Generate profile
    send_key "alt-f";
    assert_screen("AppArmor-generate-a-profile-Ok");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-o" };

    # Verify bsc#1172040
    # Enter "yast2 apparmor" again
    enter_cmd("yast2 apparmor &");
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 60);
    assert_and_click("AppArmor-Launch", timeout => 60);
    assert_screen("AppArmor-Chose-a-program-to-generate-a-profile");
    type_string("$test_file_vsftpd");
    assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
    wait_still_screen(5);
    if (!check_screen("AppArmor-Inactive-local-profile")) {
        assert_and_click("AppArmor-Chose-a-program-to-generate-a-profile-Open", timeout => 60);
        record_soft_failure("bsc#1190295, add workaround to click 'Open' again");
        send_key "tab";
    }
    send_key_until_needlematch("AppArmor-Inactive-local-profile", "tab", 2, 2);
    send_key "tab";

    # Check "View Profile"
    assert_and_click("AppArmor-View-Profile-clickview");
    send_key_until_needlematch("AppArmor-View-Profile", "tab", 2, 2);
    send_key "alt-o";
    send_key_until_needlematch("AppArmor-Inactive-local-profile", "tab", 2, 2);
    # Check "Use Profile"
    send_key "alt-u";
    assert_screen("AppArmor-Scan-system-log");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-f" };

    # Exit x11 and turn to console
    # Close the yast2 apparmor window
    save_screenshot;
    send_key "alt-f4";
    wait_still_screen(5);

    # Close the second xterm window
    save_screenshot;
    send_key "alt-f4";

    assert_screen("generic-desktop");
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;

    # Check the profiles were generated, e.g., cat it for reference
    assert_script_run("cat $test_profile_bk");
    assert_script_run("cat $test_profile_vsftpd");

    # Clean up
    assert_script_run("rm -f $test_file_bk");
    assert_script_run("rm -f $test_profile_bk");
    assert_script_run("rm -f $test_profile_vsftpd");
}

1;
