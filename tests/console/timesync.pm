# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable ntp and wait for clock to be syncronized
# before proceeding. Useful for bare-metal IPMI tests
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run 'timedatectl set-ntp true';
    assert_script_run 'chronyc makestep';
    assert_script_run 'chronyc waitsync 120 0.5', 1210;
}

1;
