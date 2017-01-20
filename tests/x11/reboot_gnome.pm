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
    my ($self) = @_;
    wait_still_screen;
    send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 7, 10;    # reboot
    assert_and_click 'logoutdialog-reboot-highlighted';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth';
        wait_still_screen;
        type_string $testapi::password, max_interval => 5;
        wait_still_screen;
        wait_screen_change {
# Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
            assert_and_click 'reboot-auth-typed', 'right';
        };
        wait_screen_change {
            # Click the 'Show Text' Option to enable the display of the typed text
            assert_and_click 'reboot-auth-showtext';
        };
        # Check the password is correct
        assert_screen 'reboot-auth-correct-password';
        # we need to kill ssh for iucvconn here,
        # because after pressing return, the system is down
        prepare_system_reboot;

        send_key "ret";

        # run only on qemu backend, e.g. svirt backend is fast enough to reboot properly
        if (check_var('BACKEND', 'qemu')) {
            sleep 10;    # wait 10 seconds to make authentication window disappear after successful authentication
            if (check_screen 'reboot-auth', 2) {
                record_soft_failure 'bsc#981299';
                send_key_until_needlematch 'generic-desktop', 'esc', 7, 10;    # close timed out authentication window
                if (check_var('DISTRI', 'sle') && !sle_version_at_least('12-SP2')) {
                    # retrying does not help on SP1 - once it fails, it will always fail
                    # so just keep it as soft failure
                    return;
                }
                send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 7, 10;    # reboot
                assert_and_click 'logoutdialog-reboot-highlighted';
            }
        }
    }
    workaround_type_encrypted_passphrase;
    # the shutdown sometimes hangs longer, so give it time
    $self->wait_boot(bootloader_time => 300);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
