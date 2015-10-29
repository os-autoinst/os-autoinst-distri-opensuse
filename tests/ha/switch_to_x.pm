use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # cleanup
    send_key "ctrl-c";
    sleep 1;
    send_key "ctrl-d";    # logout
    send_key "ctrl-d";    # logout
    sleep 2;

    save_screenshot();

    if ( check_var( "DESKTOP", "textmode" ) ) {
        send_key "ctrl-alt-f1";    # go back to first console
        assert_screen 'linux-login', 10;
    }
    else {
        send_key "ctrl-alt-f7";    # go back to X11
        sleep 2;
        send_key "backspace";      # deactivate blanking
        if ( check_screen("screenlock") ) {
            if ( check_var( "DESKTOP", "gnome" ) ) {
                send_key "esc";
                unless ( get_var("LIVETEST") ) {
                    send_key "ctrl"; # show gnome screen lock in sle 11
                    assert_screen "gnome-screenlock-password";
                    type_password;
                    send_key "ret";
                }
            }
            elsif ( check_var( "DESKTOP", "minimalx" ) ) {
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
        mouse_hide(1);
        wait_idle;
        assert_screen 'generic-desktop', 3;
    }
}

sub test_flags() {
    return { 'milestone' => 1, 'fatal' => 1, 'important' => 1 };
}

1;

# vim: set sw=4 et:
