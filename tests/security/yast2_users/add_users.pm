# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test "# yast2 users" can add users and the created user has a
#          SHA512 hashed password in /etc/shadow (starts with $6$);
#          Test to create a user on CLI by means of adduser,
#          change the password using passwd, check it is SHA512 hashed too.
#          Also verify bsc#1176714 - Password being truncated to 8 characters
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#71740 bsc#1176714

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $testuser = "testuser";
    my $pw       = "T3stpassw0rd!";
    my $f_shadow = "/etc/shadow";

    # Create a test user
    script_run("userdel -rf $testuser");
    assert_script_run("useradd -m -d \/home\/$testuser $testuser");
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
    type_string("yast2 users &\n");
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
    # There should be no this message in next window:
    # "The password is too long for the current encryption method."
    # "It will be truncated to 8 characters."
    # If no, check the user was created successfully
    assert_screen("Yast2-Users-Add-User-Created");
    wait_screen_change { send_key "alt-o" };

    # Exit x11 and turn to console
    send_key "alt-f4";
    assert_screen("generic-desktop");
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;

    # Check the password is SHA512 hashed
    validate_script_output("grep $testuser $f_shadow", sub { m/$testuser:\$6\$.*/ });

    # Cleanup: delete the test user
    assert_script_run("userdel -rf $testuser");
}

1;
