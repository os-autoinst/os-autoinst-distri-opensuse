## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait for unattended installation to finish,
# reboot and reach login prompt.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi;

sub run {
    my $reboot_page = $testapi::distri->get_reboot_page();

    $reboot_page->expect_is_shown(timeout => 1200);
    $reboot_page->reboot();

    # For agama test, it is too short time to match the grub2, so we create
    # a new needle to avoid too much needles loaded.
    assert_screen('grub2-agama', 120);
    wait_screen_change { send_key('ret') };

    my @tags = ("welcome-to", "login");
    assert_screen(\@tags, 960);
}

1;
