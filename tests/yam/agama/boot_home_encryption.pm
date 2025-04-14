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

sub run {
    my $enter_passphrase_for_home = $testapi::distri->get_enter_passphrase_for_home();
    my $grub_menu = $testapi::distri->get_grub_menu_installed_system();

    $grub_menu->expect_is_shown();
    $grub_menu->select_first_entry();

    $enter_passphrase_for_home->expect_is_shown();
    $enter_passphrase_for_home->enter();
}

sub test_flags {
    return {fatal => 1};
}

1;
