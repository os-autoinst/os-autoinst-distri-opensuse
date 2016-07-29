# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "basetest";

use utils;
use qam;
use testapi;

sub run {
    select_console 'root-console';

    pkcon_quit;

    capture_state('between-after');

    assert_script_run("zypper lr | grep test-minimal");

    zypper_call("ref");

    fully_patch_system;
    capture_state('after', 1);

    prepare_system_reboot;
    type_string "reboot\n";
    wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
