# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    wait_idle;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        sleep 3;
        type_password;
        sleep 3;
        assert_and_click 'reboot-auth-typed', 'right';    # Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
        assert_and_click 'reboot-auth-showtext';          # Click the 'Show Text' Option to enable the display of the typed text
        assert_screen 'reboot-auth-correct-password';     # Check the password is correct

        # we need to kill ssh for iucvconn here,
        # because after pressing return, the system is down
        prepare_system_reboot;

        send_key "ret";

    }
    # the shutdown sometimes hangs longer, so give it time
    wait_boot bootloader_time => 300;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}
1;

# vim: set sw=4 et:
