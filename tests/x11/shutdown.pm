# we need the package here for shutdown_sle11 to inherit it
package shutdown;
# don't use x11test, the end of this is not a desktop
use base "opensusebasetest";
use testapi;

# overloaded in sle11_shutdown
sub trigger_shutdown_gnome_button() {
    my ($self) = @_;
    send_key "ctrl-alt-delete";
}

sub run() {
    my $self = shift;

    if (check_var("DESKTOP", "kde")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

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
            assert_screen "kde-turn-off-selected", 2;
            type_string "\n";
        }
    }

    if (check_var("DESKTOP", "gnome")) {
        $self->trigger_shutdown_gnome_button();
        assert_screen 'logoutdialog', 15;
        send_key "ret";    # confirm shutdown

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth', 15;
            type_password;
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

    if (get_var("DESKTOP") =~ m/minimalx|textmode/) {
        power('off');
    }

    assert_shutdown;
}

sub test_flags() {
    return {'norollback' => 1};
}

1;
# vim: set sw=4 et:
