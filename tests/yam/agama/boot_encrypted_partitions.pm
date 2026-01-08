# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the system with encrypted partitions.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'opensusebasetest';
use testapi;

sub run {
    my $enter_passphrase_for_root = $testapi::distri->get_enter_passphrase_for_root();
    my $enter_passphrase_for_swap = $testapi::distri->get_enter_passphrase_for_swap();
    my $enter_passphrase_for_home = $testapi::distri->get_enter_passphrase_for_home();
    my $grub_menu = $testapi::distri->get_grub_menu_installed_system();

    if (get_var('ENCRYPTED_PARTITIONS') =~ /root/) {
        $enter_passphrase_for_root->expect_is_shown();
        $enter_passphrase_for_root->enter();
    }

    $grub_menu->expect_is_shown();
    $grub_menu->select_first_entry();

    if (get_var('ENCRYPTED_PARTITIONS') =~ /swap/) {
        $enter_passphrase_for_swap->expect_is_shown();
        $enter_passphrase_for_swap->enter();
    }
    if (get_var('ENCRYPTED_PARTITIONS') =~ /home/) {
        $enter_passphrase_for_home->expect_is_shown();
        $enter_passphrase_for_home->enter();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
