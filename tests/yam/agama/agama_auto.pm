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

    select_console 'root-console';
    Yam::Agama::agama_base::upload_agama_logs();
    Yam::Agama::agama_base::upload_system_logs();

    $reboot_page->reboot();
}

1;
