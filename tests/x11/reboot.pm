use base "x11step";
use testapi;

sub run() {
    my $self = shift;

    # 550_reboot_kde
    if ( $vars{DESKTOP} eq "kde" || $vars{DESKTOP} eq "gnome" ) {
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

        if ($vars{SHUTDOWN_NEEDS_AUTH}) {
            assert_screen 'reboot-auth', 15;
            sendpassword;
            send_key "ret";
        }
    }

    # 550_reboot_xfce
    if ( $vars{DESKTOP} eq "xfce" ) {
        wait_idle;
        send_key "alt-f4"; # open logout dialog
        assert_screen 'logoutdialog', 15;
        send_key "tab";    # reboot
        save_screenshot;
        send_key "ret";    # confirm
    }

    # 550_reboot_lxde
    if ( $vars{DESKTOP} eq "lxde" ) {
        wait_idle;

        #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
        x11_start_program("xterm");
        script_sudo "/sbin/reboot";
    }

    assert_screen "grub2", 100;    # wait until reboot
    if ( $vars{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    # 570_xfce_login_after_reboot
    if ( $vars{NOAUTOLOGIN} || $vars{XDMUSED} ) {
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
