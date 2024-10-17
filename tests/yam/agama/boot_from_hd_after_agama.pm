## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot to agama adding bootloader kernel parameters and expecting web ui up and running.
# At the moment redirecting to legacy handling for s390x booting.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;

use testapi;

sub run {
    my $self = shift;
    my $grub_menu = $testapi::distri->get_grub_menu_agama();

    $grub_menu->expect_is_shown();
    $grub_menu->boot_from_hd();
}

1;
