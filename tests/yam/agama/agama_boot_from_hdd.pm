## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the installed system from hard disk instead of
# booting again from the installation media.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use opensusebasetest qw(handle_uefi_boot_disk_workaround);

sub run {
    my $grub_menu = $testapi::distri->get_grub_menu_agama();

    $grub_menu->expect_is_shown();
    $grub_menu->boot_from_hd();
    'opensusebasetest'->handle_uefi_boot_disk_workaround();
}

1;
