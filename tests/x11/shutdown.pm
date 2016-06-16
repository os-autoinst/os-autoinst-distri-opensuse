# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# we need the package here for shutdown_sle11 to inherit it
package shutdown;
# don't use x11test, the end of this is not a desktop
use base "opensusebasetest";
use strict;
use testapi;
use utils;

# overloaded in sle11_shutdown
sub trigger_shutdown_gnome_button() {
    my ($self) = @_;
    send_key "ctrl-alt-delete";
}

sub run() {
    my $self = shift;

    if (check_var("DESKTOP", "kde")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen_with_soft_timeout('logoutdialog', soft_timeout => 15);

        if (get_var("PLASMA5")) {
            assert_and_click 'sddm_shutdown_option_btn';
            # sometimes not reliable, since if clicked the background
            # color of button should changed, thus check and click again
            if (check_screen("sddm_shutdown_option_btn", 1)) {
                assert_and_click 'sddm_shutdown_option_btn';
            }
            assert_and_click 'sddm_shutdown_btn';
        }
        else {
            type_string "\t";
            assert_screen_with_soft_timeout("kde-turn-off-selected", soft_timeout => 2);
            type_string "\n";
        }
    }

    if (check_var("DESKTOP", "gnome")) {
        $self->trigger_shutdown_gnome_button();
        assert_screen_with_soft_timeout('logoutdialog', soft_timeout => 15);
        send_key "ret";    # confirm shutdown

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen_with_soft_timeout('shutdown-auth', soft_timeout => 15);
            type_password;

            # we need to kill all open ssh connections before the system shuts down
            prepare_system_reboot;
            send_key "ret";
        }
    }

    if (check_var("DESKTOP", "xfce")) {
        for (1 .. 5) {
            send_key "alt-f4";    # opens log out popup after all windows closed
        }
        wait_idle;
        assert_screen_with_soft_timeout('logoutdialog', soft_timeout => 15);
        type_string "\t\t";       # select shutdown
        sleep 1;

        # assert_screen_with_soft_timeout('test-shutdown-1', soft_timeout => 3);
        type_string "\n";
    }

    if (check_var("DESKTOP", "lxde")) {
        x11_start_program("lxsession-logout");    # opens logout dialog
        assert_screen_with_soft_timeout("logoutdialog", soft_timeout => 20);
        send_key "ret";
    }

    if (get_var("DESKTOP") =~ m/minimalx|textmode/) {
        power('off');
    }

    if (check_var('BACKEND', 's390x')) {
        # make sure SUT shut down correctly
        console('x3270')->expect_3270(
            output_delim => qr/.*SIGP stop.*/,
            timeout      => 30
        );

    }

    assert_shutdown;
}

sub test_flags() {
    return {norollback => 1};
}

1;
# vim: set sw=4 et:
