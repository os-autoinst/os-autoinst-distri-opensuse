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

sub run {
    my $self = shift;
    select_console("x11");

    # 1. start yast2 keyboard
    $self->launch_yast2_module_x11("keyboard", match_timeout => 120);
    send_key "alt-k";
    wait_still_screen 1;
    send_key "g";

    # 2. Switch keymap from us to german
    send_key_until_needlematch("yast2_keyboard-layout-german", "down");
    wait_screen_change { send_key "alt-o" };
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
    type_string "xdg/su /c |&sbin&zast2 kezboard|";
    send_key("ret");
    wait_still_screen 5;
    type_password;
    send_key("ret");
    wait_still_screen 3;
    send_key "alt-k";
    wait_still_screen 2;
    send_key "e";
    send_key_until_needlematch("yast2_keyboard-layout-us", "down");
    send_key "alt-o";
    assert_screen "generic-desktop", timeout => 90;

    # 5. Reproduce bug 1142559
    x11_start_program("xterm");
    type_string "/sbin/yast2 keyboard\n";
    if (check_screen("yast2-keyboard-ui", 5)) {
        record_soft_failure "bsc#1142559, yast2 keyboard should not start as non root user";
        send_key "alt-c";
        wait_still_screen 2;
    }

    type_string "exit\n";
    assert_screen "generic-desktop", timeout => 90;


}

1;
