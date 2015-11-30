use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
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

    # Check for errors during first boot
    while (1) {
        my $ret = check_screen "generic-desktop", 400;
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
            # leave the loop as somthing wrong happened
            last;
        }
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
