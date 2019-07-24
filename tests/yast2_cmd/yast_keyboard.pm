# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST Command Line Keyboard module is behaving
#          correctly by changing keyboard layout and verifying that
#          they have been successfully set.
# Maintainer: Ming Li <mli@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {

    select_console("root-console");

    # Set keyboard layout to korean and validate.
    zypper_call("in yast2-country", timeout => 480);
    assert_script_run("yast keyboard list");
    assert_script_run("yast keyboard set layout=korean");
    validate_script_output("yast keyboard summary 2>&1", sub { m/korean/ });

    # Set keyboard layout to German.
    assert_script_run("yast keyboard set layout=german");

    # Restore keyboard settings to english-us and verify(enter using german characters).
    type_string("zast kezboard set lazout)english/us\n", wait_still_screen => 50, timeout => 80);

    validate_script_output("yast keyboard summary 2>&1", sub { m/english-us/ });

}

1;
