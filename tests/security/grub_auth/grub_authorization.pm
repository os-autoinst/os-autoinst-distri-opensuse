# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: grub2 supports restricting access to boot menu entries when
#          building their images/appliances,so that only specified
#          users can boot selected menu entries.
#
# Test steps: 1) Create custom grub config file with users/passwords to
#                authenticate the access of grub options at boot loader screen
#             2) Reboot the OS to make sure both super user and maintain user
#                can access into the corresponding grub menu entry
#             3) Wrong user/password is not able to access the grub
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81721, poo#95548, poo#97175, poo#101238, tc#1768659

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';
use version_utils 'is_sle';

my $sup_user = 'admin';
my $sup_passwd = 'pw_admin';
my $maint_user = 'maintainer';
my $maint_passwd = 'pw_maintainer';
my $test_user = 'tester';
my $test_passwd = 'pw_test';

sub switch_boot_menu {
    my $switch = shift;

    # UEFI item is available only from 15-SP4
    if (get_var('UEFI') && (!is_sle('<15-SP4'))) {
        assert_screen("grub_uefi_firmware_menu_entry", timeout => 90);
        send_key_until_needlematch("grub_auth_boot_menu_entry", "down", 6, 2) if $switch;
    }
    else {
        assert_screen("grub_auth_boot_menu_entry", timeout => 90);
    }
}

sub grub_auth_oper {
    my $para = shift;
    enter_cmd("reboot");
    if ($para eq "operator") {
        switch_boot_menu(1);
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        enter_cmd("$sup_user");
        enter_cmd("$sup_passwd");
    }
    elsif ($para eq "maintainer") {
        switch_boot_menu();
        send_key_until_needlematch("grub_auth_boot_menu_entry_maintainer", "down", 6, 2);
        send_key("ret");
        assert_screen("grub_auth_maintain_user_login");
        enter_cmd("$maint_user");
        enter_cmd("$maint_passwd");
    }
    elsif ($para eq "grub_edit_mode") {
        switch_boot_menu(1);
        send_key("e");
        assert_screen("grub_auth_super_user_login");
        enter_cmd("$sup_user");
        enter_cmd("$sup_passwd");
        assert_screen("grub_auth_edit_mode");
        send_key("ctrl-x");
    }
    elsif ($para eq "wrong_user_passwd") {
        switch_boot_menu(1);
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        enter_cmd("$test_user");
        enter_cmd("$test_passwd");
        switch_boot_menu(1);
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        enter_cmd("$sup_user");
        enter_cmd("$test_passwd");
        switch_boot_menu();
    }
}

sub run {
    select_console("root-console");

    # Check disk name, partition number and fs_type for root file system,
    # then create a new custom grub config file based on the users/passwords we definded
    assert_script_run "wget --quiet " . data_url("grub_auth/create_custom_grub.sh");
    assert_script_run "wget --quiet " . data_url("grub_auth/grub_passwd.sh");
    assert_script_run("bash grub_passwd.sh $sup_passwd > /tmp/sup_passwd_hash");
    assert_script_run("bash grub_passwd.sh $maint_passwd > /tmp/maint_passwd_hash");
    assert_script_run("bash create_custom_grub.sh $sup_user $sup_passwd $maint_user $maint_passwd");
    assert_script_run("rm -rf /tmp/sup_passwd_hash");
    assert_script_run("rm -rf /tmp/maint_passwd_hash");

    # Make sure both super user and maintainer can access the grub,
    # the super user can edit the existing boot menu entries
    foreach my $i ("operator", "maintainer", "grub_edit_mode") {
        grub_auth_oper($i);
        assert_screen("linux-login", timeout => 90);
        reset_consoles;
        select_console("root-console");
    }

    # Make sure not authorized user can not access the grub,
    # access will fail if we type the wrong password as well,
    # and the OS will switch back to boot menu entry
    grub_auth_oper("wrong_user_passwd");
}

sub test_flags {
    return {fatal => 1};
}

1;
