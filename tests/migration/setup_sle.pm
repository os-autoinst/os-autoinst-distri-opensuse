# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: After reboot, setup the system again and set HDD as registered.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use migration;

sub run {
    setup_sle;
    # Need to set HDD as registered for offline cases
    set_var('HDD_SCC_REGISTERED', 1) if get_var('KEEP_REGISTERED');
}

1;
