# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Only do very basic zypper lr test and show repos for easy investigation
# - Prints output of zypper lr --uri to serial console.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base "consoletest";
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    assert_script_run "zypper lr --uri | tee /dev/$serialdev";
}

1;
