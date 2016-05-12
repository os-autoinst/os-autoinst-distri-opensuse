# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";

use strict;

use qam;
use testapi;

sub run {
    # we should get the same IP setup after every reboot, but for now
    # we can't assert this
    script_run("diff -u /tmp/ip_a_before.log /tmp/ip_a_after.log");
    save_screenshot;
    script_run("diff -u /tmp/ip_r_before.log /tmp/ip_r_after.log");
    save_screenshot;
}

sub test_flags {
    return {important => 1};
}

1;
