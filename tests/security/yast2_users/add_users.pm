# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 users" can add users and the created user has a
#          SHA512 hashed password in /etc/shadow (starts with $6$);
#          Test to create a user on CLI by means of adduser,
#          change the password using passwd, check it is SHA512 hashed too.
#          Also verify bsc#1176714 - Password being truncated to 8 characters
# Maintainer: QE Security <none@suse.de>
# Tags: poo#71740 bsc#1176714

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';

sub run {
    my $testuser = "testuser";
    my $pw = "T3stpassw0rd!";
    my $f_shadow = "/etc/shadow";

    # Create a test user
    script_run("userdel -rf $testuser");
    assert_script_run("useradd -m -d \/home\/$testuser $testuser");
    zypper_call("in expect");
    assert_script_run(
        "expect -c 'spawn passwd $testuser; expect \"New password:\"; send \"$pw\\n\"; expect \"Retype new password:\"; send \"$pw\\n\"; interact'");

    # Check the password is SHA512 hashed
    validate_script_output("grep $testuser $f_shadow", sub { m/$testuser:\$6\$.*/ });

    # Cleanup: delete the test user
    assert_script_run("userdel -rf $testuser");

    # Turn to x11 and start "xterm"
    select_console("x11");
    x11_start_program("xterm");
    become_root;

    # Run "# yast2 users" to create a user
    enter_cmd("yast2 users &");
    # Check "SHA-512" is selected by default
    assert_and_click("Yast2-Users-Expert-Options", timeout => 180);
    assert_and_click("Yast2-Users-Expert-Options-Password-Encryption");
    assert_screen("Password-Encryption-SHA512-Selected-Bydefault");
    # Untouch the default settings and exit
    send_key "alt-c";
    # Add a user
    assert_and_click("Yast2-Users-Add");
    assert_screen("Yast2-Users-Add-User-Data");
    send_key "alt-f";
    assert_screen("Yast2-Users-Add-User-Data-UFN");
    type_string("$testuser");
    send_key "alt-p";
    assert_screen("Yast2-Users-Add-User-Data-PW");
    type_string("$pw");
    send_key "alt-c";
    assert_screen("Yast2-Users-Add-User-Data-CPW");
    type_string("$pw");
    send_key "alt-o";

    # For Tumbleweed there is an extra window for "bernhard" automatic login
    # and click "No"
    if (is_tumbleweed) {
        assert_screen("Yast2-Users-bernhard-automatic-login");
        wait_screen_change { send_key "alt-n" };
    }

    # There should be no this message in next window:
    # "The password is too long for the current encryption method."
    # "It will be truncated to 8 characters."
    # If no, check the user was created successfully
    assert_screen("Yast2-Users-Add-User-Created");
    wait_screen_change { send_key "alt-o" };
    assert_screen("yast2-user-add_xterm_nokogiri");

    # Exit x11 and turn to console
    wait_screen_change { send_key "alt-f4" };
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;

    # Check the password is SHA512 hashed
    validate_script_output("grep $testuser $f_shadow", sub { m/$testuser:\$6\$.*/ });

    # Cleanup: delete the test user
    assert_script_run("userdel -rf $testuser");
}

1;
