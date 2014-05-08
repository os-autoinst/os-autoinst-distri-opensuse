use base "basetest";
use bmwqemu;

sub is_applicable() {
    return !$ENV{LIVETEST};
}

sub run() {
    my $self = shift;

    # 550_reboot_kde
    if ( $ENV{DESKTOP} eq "kde" || $ENV{DESKTOP} eq "gnome" ) {
        waitidle;
        send_key "ctrl-alt-delete";    # reboot
        waitforneedle 'logoutdialog', 15;
        send_key "tab";
        send_key "tab";
        sleep 1;
        $self->take_screenshot;
        send_key "ret";                # confirm
    }

    # 550_reboot_xfce
    if ( $ENV{DESKTOP} eq "xfce" ) {
        send_key "ctrl-alt-delete";    # reboot
        waitforneedle 'logoutdialog', 15;

        #waitidle;
        #send_key "alt-f4"; # open popup
        #waitidle;
        send_key "tab";    # reboot
        sleep 1;
        $self->take_screenshot;
        send_key "ret";    # confirm
    }

    # 550_reboot_lxde
    if ( $ENV{DESKTOP} eq "lxde" ) {
        waitidle;

        #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
        x11_start_program("xterm");
        script_sudo "/sbin/reboot", 0;
    }

    waitforneedle( "bootloader", 100 );    # wait until reboot
    if ( $ENV{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    # 570_xfce_login_after_reboot
    if ( $ENV{NOAUTOLOGIN} || $ENV{XDMUSED} ) {
        waitforneedle( 'displaymanager', 200 );
        waitidle;

        # log in
        type_string $username. "\n";
        sleep 1;
        type_string $password. "\n";
    }

    waitforneedle 'test-consoletest_finish-1', 300;
    mouse_hide(1);
}

sub test_flags() {
    return { 'milestone' => 1 };
}
1;

# vim: set sw=4 et:
