# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: reboot gnome with or without authentication and ensure proper boot
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    wait_still_screen;
    send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 7, 10;    # reboot
    assert_and_click 'logoutdialog-reboot-highlighted';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth';
        wait_still_screen;
        type_password;
        wait_still_screen;
        wait_screen_change {
            assert_and_click 'reboot-auth-typed', 'right';                  # Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
        };
        wait_screen_change {
            assert_and_click 'reboot-auth-showtext';                        # Click the 'Show Text' Option to enable the display of the typed text
        };
        # Check the password is correct
        assert_screen 'reboot-auth-correct-password';
        # we need to kill ssh for iucvconn here,
        # because after pressing return, the system is down
        prepare_system_reboot;

        send_key "ret";

        wait_still_screen 4, 7;    # wait max. 7 seconds to make authentication window disappear after successful authentication
        if (check_screen 'reboot-auth', 3) {
            record_soft_failure 'bsc#981299';
            send_key_until_needlematch 'generic-desktop', 'esc',             7, 10;    # close timed out authentication window
            send_key_until_needlematch 'logoutdialog',    'ctrl-alt-delete', 7, 10;    # reboot
            assert_and_click 'logoutdialog-reboot-highlighted';
        }
    }
    workaround_type_encrypted_passphrase;
    # the shutdown sometimes hangs longer, so give it time
    wait_boot bootloader_time => 300;
}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
