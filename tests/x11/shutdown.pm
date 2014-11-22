use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    if ( check_var("DESKTOP", "kde") ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

        type_string "\t";
        assert_screen "kde-turn-off-selected", 2;
        type_string "\n";
    }

    if ( check_var("DESKTOP", "gnome") ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;
        send_key "ret";                # confirm shutdown

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth', 15;
            type_password;
            send_key "ret";
        }
    }

    if ( check_var("DESKTOP", "xfce") ) {
        for ( 1 .. 5 ) {
            send_key "alt-f4";         # opens log out popup after all windows closed
        }
        wait_idle;
        assert_screen 'logoutdialog', 15;
        type_string "\t\t";          # select shutdown
        sleep 1;

        # assert_screen 'test-shutdown-1', 3;
        type_string "\n";
    }

    if ( check_var("DESKTOP", "lxde") ) {
        x11_start_program("lxsession-logout"); # opens logout dialog
        assert_screen "logoutdialog", 20;
        send_key "ret";
    }

    if ( get_var("DESKTOP") =~ m/minimalx|textmode/ ) {
        backend_send "system_powerdown";    # shutdown

        # assert_screen 'test-shutdown-2', 3;
        # send_key "ctrl-alt-f1"; # work-around for LXDE bug 619769 ; not needed in Factory anymore
    }

    # qemu is not reliable in sending last screenshot, so don't assert here
    check_screen "machine-is-shutdown", 30;
}

sub test_flags() {
    return { 'norollback' => 1 };
}

1;
# vim: set sw=4 et:
