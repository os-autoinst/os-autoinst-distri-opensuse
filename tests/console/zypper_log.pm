# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the zypper-log tool
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    select_console 'root-console';

    # zypper-log is recommended by zypper (but that doesn't count on livesystems and on jeos)
    if (is_jeos || is_livecd) {
        zypper_call 'in zypper-log';
    }

    if (script_run('zypper-log') != 0) {
        record_soft_failure 'bsc#1156158: zypper-log needs python2 but only python3 is installed by default';
        zypper_call 'in python2';
    }

    script_run("zypper some_wrong_arg_that_will_show_up_in_the_log");
    assert_script_run("zypper-log | grep some_wrong_arg_that_will_show_up_in_the_log");
    assert_script_run("zypper-log -r3");
}

1;
