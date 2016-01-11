use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # cleanup
    type_string "loginctl --no-pager\n";
    sleep 2;
    save_screenshot();

    script_sudo "systemctl unmask packagekit.service";

    send_key "ctrl-c";
    sleep 1;
    send_key "ctrl-d";    # logout
    sleep 2;

    save_screenshot();

    if (check_var("DESKTOP", "textmode")) {
        send_key "ctrl-alt-f1";    # go back to first console
        assert_screen 'linux-login', 10;
    }
    else {
        send_key "ctrl-alt-f7";    # go back to X11
        sleep 2;
        send_key "backspace";      # deactivate blanking
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
            record_soft_failure;
            send_key 'alt-c';
            sleep 30;
        }
        wait_idle;
        mouse_hide(1);
        if (check_var("DESKTOP", "awesome")) {
            assert_screen 'displaymanager', 200;
        }
        else {
            assert_screen 'generic-desktop';
        }
    }
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;

# vim: set sw=4 et:
