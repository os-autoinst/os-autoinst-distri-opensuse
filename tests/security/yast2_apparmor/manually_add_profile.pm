# Copyright (C) 2020-2021 SUSE LLC
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
# Summary: Test "# yast2 apparmor" can manually add profile,
#          also verify Bug 1172040 - YaST2 apparmor profile creation:
#          "View profile" does nothing
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#70537, tc#1741266

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self)              = shift;
    my $test_file           = "/usr/bin/cat";
    my $test_profile        = "/etc/apparmor.d/usr.bin.cat";
    my $test_file_bk        = "/usr/bin/cat_bk";
    my $test_profile_bk     = "/etc/apparmor.d/usr.bin.cat_bk";
    my $test_file_vsftpd    = "/usr/sbin/vsftpd";
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
    type_string("yast2 apparmor &\n");

    # Enter "Manually Add Profile" to generate a profile for a program
    # "marked as a program that should not have its own profile",
    # it should be failed
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 60);
    send_key "alt-l";
    assert_screen("AppArmor-Chose-a-program-to-generate-a-profile", timeout => 90);
    type_string("$test_file");
    send_key "alt-o";
    assert_screen("AppArmor-generate-a-profile-Error");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-o" };

    # Enter "yast2 apparmor" again
    type_string("yast2 apparmor &\n");

    # Enter "Manually Add Profile" to generate a profile for a program
    # *NOT* "marked as a program that should not have its own profile",
    # it should be succeeded
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 60);
    send_key "alt-l";
    assert_screen("AppArmor-Chose-a-program-to-generate-a-profile");
    type_string("$test_file_bk");
    send_key "alt-o";
    assert_screen("AppArmor-Scan-system-log");
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
    type_string("yast2 apparmor &\n");
    assert_and_click("AppArmor-Manually-Add-Profile", timeout => 60);
    send_key "alt-l";
    assert_screen("AppArmor-Chose-a-program-to-generate-a-profile");
    type_string("$test_file_vsftpd");
    send_key "alt-o";
    assert_screen("AppArmor-Inactive-local-profile");
    # Check "View Profile"
    send_key "alt-v";
    assert_screen("AppArmor-View-Profile");
    send_key "alt-o";
    assert_screen("AppArmor-Inactive-local-profile");
    # Check "Use Profile"
    send_key "alt-u";
    assert_screen("AppArmor-Scan-system-log");
    # Exit "yast2 apparmor"
    wait_screen_change { send_key "alt-f" };

    # Exit x11 and turn to console
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
