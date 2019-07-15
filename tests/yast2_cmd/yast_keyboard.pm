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

    # Set keyboard layout to korean and validate
    select_console("root-console");
    zypper_call("in yast2-country", timeout => 480);
    assert_script_run("yast keyboard list");
    assert_script_run("yast keyboard set layout=korean");
    validate_script_output("yast keyboard summary 2>&1",                    sub { m/Current\s+Keyboard\s+Layout:/ });
    validate_script_output("localectl",                                     sub { m/korean/ });
    validate_script_output("grep -i YAST_KEYBOARD /etc/sysconfig/keyboard", sub { m/korean/ });

    # Set keyboard layout to German and validate
    assert_script_run("yast keyboard set layout=german");
    type_string "`1234567890-=[;'";
    assert_screen "yast2_keyboard_layout_cmd_test";
    send_key 'ctrl-u';

    # Restore keyboard settings to english-us(select root-virtio-terminal console here, otherwise openqa will not run properly in the german keyboard layout)
    select_console('root-virtio-terminal');
    assert_script_run("yast keyboard set layout=english-us");
    validate_script_output("yast keyboard summary 2>&1", sub { m/english-us/ });

    select_console("root-console");

}

1;
