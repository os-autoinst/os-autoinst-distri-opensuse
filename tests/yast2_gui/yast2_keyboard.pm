# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country xdg-utils
# Summary: this test checks that YaST2's Keyboard module is behaving
#          correctly by changing keyboard layout and verifying that
#          they have been successfully set.
# - Start yast2 keyboard
# - Switch keymap from us to german
# - Use gedit to enter german characters to verify keyboard layout
# - Simulate german keystrokes to switch back us keymap
# - Expose and reproduce bsc#1142559 which was found during writing this script.
# Maintainer: Ming Li <mli@suse.com>

=head1 Create regression test for keyboard layout and verify

Reference:
https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.17
 
1. Start yast2 keyboard
2. Switch keymap from us to german
3. Use gedit to enter german characters to verify keyboard layout
4. Simulate german keystrokes to switch back us keymap
5. Expose and reproduce bsc#1142559 which was found during writing this script.
 
=cut

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";

sub run {
    select_console("x11");
    my $accept_keybind = is_sle("<=15-SP1") ? "alt-o" : "alt-a";

    # 1. start yast2 keyboard
    y2_module_guitest::launch_yast2_module_x11("keyboard", match_timeout => 120);
    send_key "alt-k";
    wait_still_screen 1;
    send_key "g";

    # 2. Switch keymap from us to german
    send_key_until_needlematch("yast2_keyboard-layout-german", "down");
    wait_screen_change { send_key $accept_keybind };
    assert_screen "generic-desktop", timeout => 90;

    # 3. Use gedit to enter german characters to verify keyboard layout
    x11_start_program("gedit", match_timeout => 120);
    wait_screen_change { type_string "`1234567890-=[;'" };
    assert_screen "yast2_keyboard_layout_gedit_test";
    send_key "alt-f4";
    assert_screen "gedit-save-changes";
    send_key "alt-w";
    assert_screen "generic-desktop", timeout => 90;

    # 4. simulate german keystrokes to switch back us keymap
    send_key "alt-f2";
    wait_screen_change { type_string "xdg/su /c |&sbin&zast2 kezboard|" };
    send_key_until_needlematch('root-auth-dialog', 'ret', 3, 3);
    wait_still_screen 2;
    type_password;
    send_key("ret");
    # bumped timeout to 10 to avoid loosing focus with desktop notification
    wait_still_screen 10;
    send_key "alt-k";
    wait_still_screen 2;
    send_key "e";
    send_key "n" if is_sle("15-SP2+");
    send_key_until_needlematch("yast2_keyboard-layout-us", "down");
    send_key $accept_keybind;
    assert_screen "generic-desktop", timeout => 90;

    # 5. Reproduce bug 1142559
    x11_start_program("xterm");
    enter_cmd "/sbin/yast2 keyboard";
    if (check_screen("yast2-keyboard-ui", 5)) {
        record_soft_failure "bsc#1142559, yast2 keyboard should not start as non root user";
        send_key "alt-c";
        wait_still_screen 2;
    }

    enter_cmd "exit";
    assert_screen "generic-desktop", timeout => 90;


}

1;
