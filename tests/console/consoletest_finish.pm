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
use testapi;
use strict;

sub run() {
    my $self = shift;

    my $console = select_console 'root-console';
    # cleanup
    type_string "loginctl --no-pager\n";
    sleep 2;
    save_screenshot();

    script_run "systemctl unmask packagekit.service";

    # logout root (and later user) so they don't block logout
    # in KDE
    type_string "exit\n";
    $console->reset;

    $console = select_console 'user-console';

    send_key "ctrl-c";
    sleep 1;
    type_string "exit\n";    # logout
    $console->reset;
    sleep 2;

    save_screenshot();

    if (!check_var("DESKTOP", "textmode")) {
        select_console('x11');
        sleep 2;
        send_key "backspace";    # deactivate blanking
        if (check_screen("screenlock")) {
            if (check_var("DESKTOP", "gnome")) {
                send_key "esc";
                unless (get_var("LIVETEST")) {
                    send_key "ctrl";    # show gnome screen lock in sle 11

                    # it is possible for GNOME not yet to ask for a password
                    # switching to tty1 then back to 7, where GNOME runs, withing five minutes
                    # does not lock with a password - in most cases we take long enough, but some
                    # console tests are just too quick
                    if (check_screen "gnome-screenlock-password") {
                        type_password;
                        send_key "ret";
                    }
                }
            }
            elsif (check_var("DESKTOP", "minimalx")) {
                type_string "$username";
                save_screenshot();
                send_key "ret";
                type_password;
                send_key "ret";
            }
            else {
                type_password;
                send_key "ret";
            }
        }

        # workaround for bug 834165. Apper should not try to
        # refresh repos when the console is not active:
        if (get_var("DESKTOP", '') eq 'kde' && check_screen "apper-refresh-popup-bnc834165") {
            record_soft_failure 'bsc#834165';
            send_key 'alt-c';
            sleep 30;
        }
        wait_idle;
        if (get_var("DESKTOP_MINIMALX_INSTONLY")) {
            # Desired wm was just installed and needs x11_login
            assert_screen 'displaymanager', 200;
        }
        else {
            mouse_hide(1);
            assert_screen 'generic-desktop';
        }
    }
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;

# vim: set sw=4 et:
