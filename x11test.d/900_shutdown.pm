use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;

    if ( $vars{DESKTOP} eq "kde" ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

        type_string "\t";
        assert_screen "kde-turn-off-selected", 2;
        type_string "\n";
    }

    if ( $vars{DESKTOP} eq "gnome" ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;
        send_key "ret";                # confirm shutdown

        if ($vars{SHUTDOWN_NEEDS_AUTH}) {
            assert_screen 'shutdown-auth', 15;
            sendpassword;
            send_key "ret";
        }
    }

    if ( $vars{DESKTOP} eq "xfce" ) {
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

    if ( $vars{DESKTOP} =~ m/lxde|minimalx|textmode/ ) {
        qemusend "system_powerdown";    # shutdown

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
