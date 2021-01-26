# Copyright (C) 2021 SUSE LLC
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
# Summary: grub2 supports restricting access to boot menu entries when
#          building their images/appliances,so that only specified
#          users can boot selected menu entries.
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#81721, tc#1768659

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';

my $sup_user     = 'admin';
my $sup_passwd   = 'pw_admin';
my $maint_user   = 'maintainer';
my $maint_passwd = 'pw_maintainer';
my $test_user    = 'tester';
my $test_passwd  = 'pw_test';

sub grub_auth_oper {
    my $para = shift;
    type_string("reboot\n");
    if ($para eq "operator") {
        assert_screen("grub_auth_boot_menu_entry");
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        type_string("$sup_user\n");
        type_string("$sup_passwd\n");
    }
    elsif ($para eq "maintainer") {
        assert_screen("grub_auth_boot_menu_entry_maintainer");
        send_key("down");
        send_key("ret");
        assert_screen("grub_auth_maintain_user_login");
        type_string("$maint_user\n");
        type_string("$maint_passwd\n");
    }
    elsif ($para eq "grub_edit_mode") {
        assert_screen("grub_auth_boot_menu_entry");
        send_key("e");
        assert_screen("grub_auth_super_user_login");
        type_string("$sup_user\n");
        type_string("$sup_passwd\n");
        assert_screen("grub_auth_edit_mode");
        send_key("ctrl-x");
    }
    elsif ($para eq "wrong_user_passwd") {
        assert_screen("grub_auth_boot_menu_entry");
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        type_string("$test_user\n");
        type_string("$test_passwd\n");
        assert_screen("grub_auth_boot_menu_entry");
        send_key("ret");
        assert_screen("grub_auth_super_user_login");
        type_string("$sup_user\n");
        type_string("$test_passwd\n");
        assert_screen("grub_auth_boot_menu_entry");
    }
}

sub run {
    select_console("root-console");

    # Check disk name, partition number and fs_type for root file system,
    # then create a new custom grub config file based on the users/passwords we definded
    assert_script_run "wget --quiet " . data_url("grub_auth/create_custom_grub.sh");
    assert_script_run("bash create_custom_grub.sh $sup_user $sup_passwd $maint_user $maint_passwd");

    # Make sure both super user and maintainer can access the grub
    # the sure user can edit the existing boot menu entries
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
