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
    system_login;

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    capture_state('between-after');

    assert_script_run("zypper lr | grep test-minimal");

    my $ret = zypper_call("ref");
    die "zypper failed with code $ret" unless $ret == 0;

    fully_patch_system;
    capture_state('after', 1);

    prepare_system_reboot;
    type_string "reboot\n";

    reset_consoles;

    # wait for the reboot
    system_login;
}

sub test_flags {
    return {fatal => 1};
}

1;
