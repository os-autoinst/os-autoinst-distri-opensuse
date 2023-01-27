# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi;
use utils;

sub run {
    # Set root password
    assert_script_run('dinstallerctl rootuser password nots3cr3t');
    # Select disk for installation
    my @disks = script_output('dinstallerctl storage available_devices');
    assert_script_run("dinstallerctl storage selected_devices $disks[0]");
}

1;
