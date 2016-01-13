# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
        return;
    }

    if (check_var('DESKTOP', 'awesome')) {
        assert_screen 'displaymanager', 200;
        return;
    }

    if (get_var("NOAUTOLOGIN")) {
        my $ret = assert_screen 'displaymanager', 200;
        mouse_hide();
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        if ($ret->{needle}->has_tag("sddm")) {
            # make sure choose plasma5 session
            assert_and_click "sddm-sessions-list";
            assert_and_click "sddm-sessions-plasma5";
            assert_and_click "sddm-password-input";
        }
        else {
            send_key "ret";
            wait_idle;
        }
        type_string "$password";
        send_key "ret";
    }

    # 2 is not magic number here, we're using 400 seconds in the past,
    # decrease the timeout to 300 seconds now thus doing two times.
    my $retry = 2;
    # Check for errors during first boot
    while ($retry) {
        # GNOME and KDE get into screenlock after 5 minutes without activities.
        # using 300 seconds here then we can get the wrong desktop screenshot at least
        # in case desktop screenshot changed, otherwise we get the screenlock screenshot.
        my $ret = check_screen "generic-desktop", 300;
        if ($ret) {
            mouse_hide();
            last;
        }
        else {
            # special case for KDE
            if (check_var("DESKTOP", "kde")) {
                # KDE Greeter was removed from Leap 42.1 though
                if (check_screen "kde-greeter", 60) {
                    send_key "esc";
                    next;
                }
                if (check_screen "drkonqi-crash") {
                    # handle for KDE greeter crashed and drkonqi popup
                    send_key "alt-d";

                    # maximize
                    send_key "alt-shift-f3";
                    sleep 8;
                    save_screenshot;
                    send_key "alt-c";
                    next;

                }
            }
        }
        $retry--;
    }
    # get the last screenshot
    assert_screen "generic-desktop", 5;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

1;

# vim: set sw=4 et:
