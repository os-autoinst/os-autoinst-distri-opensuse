## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the system for encryption scenario.
# - {Enter passphrase for root partition for full disk encryption}.
# - Select first entry to boot in grub2
# - {Enter passphrase for swap partition for full disk encryption}.
# = {Enter passphrase for home partition for home encryption}.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    my $enter_passphrase_for_root = $testapi::distri->get_enter_passphrase_for_root();
    my $enter_passphrase_for_swap = $testapi::distri->get_enter_passphrase_for_swap();
    my $enter_passphrase_for_home = $testapi::distri->get_enter_passphrase_for_home();
    my $grub_menu = $testapi::distri->get_grub_menu_installed_system();

    if (get_var('ENCRYPTED_PARTITIONS_CONTAIN_ROOT')) {
        $enter_passphrase_for_root->expect_is_shown();
        $enter_passphrase_for_root->enter();
    }

    $grub_menu->expect_is_shown();
    $grub_menu->select_first_entry();

    if (get_var('ENCRYPTED_PARTITIONS_CONTAIN_ROOT')) {
        $enter_passphrase_for_swap->expect_is_shown();
        $enter_passphrase_for_swap->enter();
    }
    if (get_var('ENCRYPTED_PARTITIONS_CONTAIN_HOME')) {
        $enter_passphrase_for_home->expect_is_shown();
        $enter_passphrase_for_home->enter();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
