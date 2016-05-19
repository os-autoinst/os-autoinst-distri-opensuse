# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


use base "basetest";

use strict;

use utils;
use qam;
use testapi;

sub run {
    select_console 'root-console';

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    if (!get_var('MINIMAL_TEST_REPO')) {
        die "no repository with update";
    }

    capture_state('before');

    my $repo = get_var('MINIMAL_TEST_REPO');
    zypper_call("ar -f $repo test-minimal");

    zypper_call("ref");

    zypper_call(qq{in -l -y -t patch \$(zypper patches | awk -F "|" '/test-minimal/ { print \$2;}')}, [0, 102, 103]);

    capture_state('between', 1);

    prepare_system_reboot;
    type_string "reboot\n";
    wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
