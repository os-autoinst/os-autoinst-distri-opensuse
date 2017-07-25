# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy first run
# Maintainer: SeroSun <sunyong0511@gmail.com>
# Tags: tc#1248872

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    mouse_hide();
    x11_start_program("tomboy note");
    while (check_screen "tomboy_command_not_found", 5) {
        wait_still_screen;
        send_key "ret";
    }
    wait_still_screen(3);

    # open the menu
    send_key "alt-f12";
    check_screen "tomboy_menu", 5;
    wait_screen_change { send_key 'esc' };
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
