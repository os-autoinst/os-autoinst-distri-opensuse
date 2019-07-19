# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST2's Keyboard module is behaving
#          correctly by changing keyboard layout and verifying that
#          they have been successfully set.
# Maintainer: Ming Li <mli@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    # CLI validate yast keyboard module
    select_console("x11");
    x11_start_program("xterm");
    become_root;
    assert_script_run("yast keyboard list");
    assert_script_run("yast keyboard set layout=korean");
    validate_script_output("yast keyboard summary 2>&1", sub { m/Current\s+Keyboard\s+Layout:/ });
    validate_script_output("localectl",                  sub { m/korean/ });
    send_key "alt-f4";

    # Set keyboard layout to German with yast2
    $self->launch_yast2_module_x11("keyboard", match_timeout => 120);
    send_key "alt-k";
    send_key "home";
    send_key_until_needlematch("yast2_keyboard-layout-german", "down");
    wait_screen_change { send_key "alt-o" };
    assert_screen "generic-desktop";

    # Use gedit to verify keyboard layout
    x11_start_program("gedit", match_timeout => 120);
    wait_screen_change { type_string "`1234567890-=[;'" };
    assert_screen "yast2_keyboard_layout_gedit_test";
    send_key "alt-f4";
    assert_screen "gedit-save-changes";
    send_key "alt-w";
    assert_screen "generic-desktop";

    # Restore keyboard settings to english-us(select root-virtio-terminal console here, otherwise openqa will not run properly in the german keyboard layout)
    select_console('root-virtio-terminal');
    assert_script_run("yast keyboard set layout=english-us");
    validate_script_output("yast keyboard summary 2>&1", sub { m/english-us/ });

    select_console("x11");

}

1;
