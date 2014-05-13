use base "basetest";
use bmwqemu;

sub is_applicable() {
    return !$vars{LIVETEST};
}

sub run() {
    my $self = shift;

    # 550_reboot_kde
    if ( $vars{DESKTOP} eq "kde" || $vars{DESKTOP} eq "gnome" ) {
        wait_idle;
        send_key "ctrl-alt-delete";    # reboot
        assert_screen 'logoutdialog', 15;
        send_key "tab";
        send_key "tab";
        sleep 1;
        $self->take_screenshot;
        send_key "ret";                # confirm
    }

    # 550_reboot_xfce
    if ( $vars{DESKTOP} eq "xfce" ) {
        send_key "ctrl-alt-delete";    # reboot
        assert_screen 'logoutdialog', 15;

        #wait_idle;
        #send_key "alt-f4"; # open popup
        #wait_idle;
        send_key "tab";    # reboot
        sleep 1;
        $self->take_screenshot;
        send_key "ret";    # confirm
    }

    # 550_reboot_lxde
    if ( $vars{DESKTOP} eq "lxde" ) {
        wait_idle;

        #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
        x11_start_program("xterm");
        script_sudo "/sbin/reboot", 0;
    }

    assert_screen  "bootloader", 100 ;    # wait until reboot
    if ( $vars{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    # 570_xfce_login_after_reboot
    if ( $vars{NOAUTOLOGIN} || $vars{XDMUSED} ) {
        assert_screen  'displaymanager', 200 ;
        wait_idle;

        # log in
        type_string $username. "\n";
        sleep 1;
        type_string $password. "\n";
    }

    assert_screen 'test-consoletest_finish-1', 300;
    mouse_hide(1);
}

sub test_flags() {
    return { 'milestone' => 1 };
}
1;

# vim: set sw=4 et:
