## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the installed system from hard disk instead of
# booting again from the installation media.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "installbasetest";
use Utils::Architectures qw(is_aarch64);
use opensusebasetest;

sub run {
    my $grub_menu = $testapi::distri->get_grub_menu_agama();

    $grub_menu->expect_is_shown();
    $grub_menu->boot_from_hd();
    opensusebasetest::handle_uefi_boot_disk_workaround() if is_aarch64;
}

1;
