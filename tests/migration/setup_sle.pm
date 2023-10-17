# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: After reboot, setup the system again and set HDD as registered.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use migration;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    # https://bugzilla.suse.com/show_bug.cgi?id=1205290#c3
    systemctl('restart systemd-vconsole-setup.service') if (is_sle('=12-SP5'));

    # Stop packagekitd
    quit_packagekit;
    script_run("source /etc/bash.bashrc.local", die_on_timeout => 0);
}

1;
