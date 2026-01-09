# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

use testapi;
use utils;

sub run {
    $testapi::password = 'linux';
    assert_screen('suse-alp-containerhost-os', 120);
    select_console('root-console');
}

1;
