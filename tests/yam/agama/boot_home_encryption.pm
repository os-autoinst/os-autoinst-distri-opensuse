## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the system for home encryption scenario.
# - Select first entry to boot in grub2
# - Enter passphrase for home partition.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends;

sub run {
    my $enter_passphrase_for_home = $testapi::distri->get_enter_passphrase_for_home();
    my $grub_menu = $testapi::distri->get_grub_menu_installed_system();

    if (is_svirt) {
        select_console('svirt');

        # enter passphrase for home encryption
        wait_serial("Please enter passphrase for disk cr_home.*", 300);
        type_line_svirt '', expect => "Please enter passphrase for disk cr_home.*", timeout => 100, fail_message => 'Could not find "enter passphrase" prompt';
        type_line_svirt "$password";
    }
    else {
        $grub_menu->expect_is_shown();
        $grub_menu->select_first_entry();

        $enter_passphrase_for_home->expect_is_shown();
        $enter_passphrase_for_home->enter();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
