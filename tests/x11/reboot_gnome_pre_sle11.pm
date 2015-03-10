use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    wait_idle;
    send_key "alt-f1"; # applicationsmenu
    my $selected = check_screen 'shutdown_button', 0;
    if (!$selected) {
        $self->key_round('shutdown_button', 'tab', 20); # press tab till is shutdown button selected
    }

    send_key "ret"; # press shutdown button
    assert_screen "logoutdialog", 15;
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

    # qemu is not reliable in sending last screenshot, so don't assert here
    check_screen "machine-is-shutdown", 30;
    power('reset');
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
