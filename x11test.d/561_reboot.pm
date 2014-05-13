use base "basetest";
use bmwqemu;

sub is_applicable() {
    return !$envs->{LIVETEST};
}

sub run() {
    my $self = shift;

    # 550_reboot_kde
    if ( $envs->{DESKTOP} eq "kde" || $envs->{DESKTOP} eq "gnome" ) {
        waitidle;
        send_key "ctrl-alt-delete";    # reboot
        assert_screen 'logoutdialog', 15;
        send_key "tab";
        send_key "tab";
        sleep 1;
        $self->take_screenshot;
        send_key "ret";                # confirm
    }

    # 550_reboot_xfce
    if ( $envs->{DESKTOP} eq "xfce" ) {
        send_key "ctrl-alt-delete";    # reboot
        assert_screen 'logoutdialog', 15;

        #waitidle;
        #send_key "alt-f4"; # open popup
        #waitidle;
        send_key "tab";    # reboot
        sleep 1;
        $self->take_screenshot;
        send_key "ret";    # confirm
    }

    # 550_reboot_lxde
    if ( $envs->{DESKTOP} eq "lxde" ) {
        waitidle;

        #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
        x11_start_program("xterm");
        script_sudo "/sbin/reboot", 0;
    }

    assert_screen  "bootloader", 100 ;    # wait until reboot
    if ( $envs->{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    # 570_xfce_login_after_reboot
    if ( $envs->{NOAUTOLOGIN} || $envs->{XDMUSED} ) {
        assert_screen  'displaymanager', 200 ;
        waitidle;

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
