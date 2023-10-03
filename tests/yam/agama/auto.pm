## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::agama::agama_base;
use strict;
use warnings;

use testapi;
use utils 'clear_console';

sub run {
    assert_screen('agama-install-finished', 1200);

    select_console 'root-console';
    clear_console;
    enter_cmd "reboot";

    # For agama test, it is too short time to match the grub2, so we create
    # a new needle to avoid too much needles loaded.
    assert_screen('grub2-agama', 120);
    wait_screen_change { send_key 'ret' };

    my @tags = ("welcome-to", "login");
    assert_screen \@tags, 960;
}

1;
