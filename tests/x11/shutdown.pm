# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initiate a system shutdown, taking care of differences between the desktops
#   don't use x11test, the end of this is not a desktop
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "opensusebasetest";
use strict;
use testapi;
use utils;


sub run() {
    my $self = shift;
    # make some information available on common systems to debug shutdown
    # issues
    if (get_var('DESKTOP', '') =~ qr/gnome|kde/) {
        x11_start_program('xterm');
        script_sudo(q{echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf});
        script_sudo(q{echo 'MaxLevelConsole=debug' >> /etc/systemd/journald.conf});
        script_sudo(qq{echo 'TTYPath=/dev/$serialdev' >> /etc/systemd/journald.conf});
        script_sudo(q{systemctl restart systemd-journald});
        type_string("exit\n");
    }
    $self->{await_shutdown} = 0;

    if (check_var("DESKTOP", "kde")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

        if (get_var("PLASMA5")) {
            assert_and_click 'sddm_shutdown_option_btn';
            if (check_screen([qw(sddm_shutdown_option_btn sddm_shutdown_btn)], 3)) {
                # sometimes not reliable, since if clicked the background
                # color of button should changed, thus check and click again
                if (match_has_tag('sddm_shutdown_option_btn')) {
                    assert_and_click 'sddm_shutdown_option_btn';
                }
                # plasma < 5.8
                elsif (match_has_tag('sddm_shutdown_btn')) {
                    assert_and_click 'sddm_shutdown_btn';
                }
            }
        }
        else {
            type_string "\t";
            assert_screen "kde-turn-off-selected", 2;
            type_string "\n";
        }
    }

    if (check_var("DESKTOP", "gnome")) {
        send_key "ctrl-alt-delete";
        assert_screen 'logoutdialog', 15;
        send_key "ret";    # confirm shutdown

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth', 15;
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
        assert_screen 'logoutdialog', 15;
        type_string "\t\t";       # select shutdown
        sleep 1;

        # assert_screen 'test-shutdown-1', 3;
        type_string "\n";
    }

    if (check_var("DESKTOP", "lxde")) {
        x11_start_program("lxsession-logout");    # opens logout dialog
        assert_screen "logoutdialog", 20;
        send_key "ret";
    }

    if (check_var("DESKTOP", "lxqt")) {
        x11_start_program("shutdown");            # opens logout dialog
        assert_screen "lxqt_logoutdialog", 20;
        send_key "ret";
    }
    if (check_var("DESKTOP", "enlightenment")) {
        send_key "ctrl-alt-delete";               # shutdown
        assert_screen 'logoutdialog', 15;
        assert_and_click 'enlightenment_shutdown_btn';
    }

    if (check_var('DESKTOP', 'awesome')) {
        assert_and_click 'awesome-menu-main';
        assert_and_click 'awesome-menu-system';
        assert_and_click 'awesome-menu-shutdown';
    }

    if (check_var("DESKTOP", "mate")) {
        x11_start_program("mate-session-save --shutdown-dialog");
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'mate_logoutdialog', 15;
        assert_and_click 'mate_shutdown_btn';
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

    $self->{await_shutdown} = 1;
    assert_shutdown;
}

sub test_flags() {
    return {norollback => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    # In case plymouth splash shows up and the shutdown is blocked, show
    # console logs - save screen of console (plymouth splash screen in disabled at boottime)
    send_key('esc') if $self->{await_shutdown};
    save_screenshot;
}

1;
# vim: set sw=4 et:
