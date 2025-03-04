## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot to agama mediacheck tool expecting good integrity check.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    my $grub_menu = $testapi::distri->get_grub_menu_agama();
    my $mediacheck_page = $testapi::distri->get_checking_data_integrity();

    $grub_menu->expect_is_shown();
    $grub_menu->select_checking_data_integrity_entry();
    $mediacheck_page->expect_successful_result();
}

1;
