use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # 550_reboot_kde
    if ( check_var("DESKTOP", "kde") || get_var("DESKTOP") eq "gnome" ) {
        wait_idle;
        send_key "ctrl-alt-delete";    # reboot
        assert_screen 'logoutdialog', 15;
        send_key "tab";
        send_key "tab";
        my $ret;
        for (my $counter = 10; $counter > 0; $counter--) {
            $ret = check_screen "logoutdialog-reboot-highlighted", 3;
            if ( defined($ret) ) {
                last;
            }
            else {
                send_key "tab";
            }
        }
        # report the failure or green
        unless ( defined($ret) ) {
            assert_screen "logoutdialog-reboot-highlighted", 1;
        }
        send_key "ret";                # confirm

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'reboot-auth', 15;
            type_password;
            send_key "ret";
        }
    }

    # 550_reboot_xfce
    if ( check_var("DESKTOP", "xfce") ) {
        wait_idle;
        send_key "alt-f4"; # open logout dialog
        assert_screen 'logoutdialog', 15;
        send_key "tab";    # reboot
        save_screenshot;
        send_key "ret";    # confirm
    }

    # 550_reboot_lxde
    if ( check_var("DESKTOP", "lxde") ) {
        wait_idle;

        #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
        x11_start_program("xterm");
        script_sudo "/sbin/reboot";
    }

    assert_screen "grub2", 100;    # wait until reboot
    if ( get_var("ENCRYPT") ) {
        assert_screen("encrypted-disk-password-prompt");
        type_password();    # enter PW at boot
        send_key "ret";
    }

    # 570_xfce_login_after_reboot
    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        assert_screen 'displaymanager', 200;
        wait_idle;

        # log in
        type_string $username. "\n";
        type_string $password. "\n";
    }

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);
}

sub test_flags() {
    return { 'milestone' => 1 };
}
1;

# vim: set sw=4 et:
