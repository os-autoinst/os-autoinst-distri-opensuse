# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';

use testapi;
use utils;
use power_action_utils qw(power_action);


sub run {
    power_action('reboot', textmode => 1);
    $testapi::password = 'nots3cr3t';
}

1;
