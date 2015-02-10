use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

sub powerdialog() {
    wait_idle;
    send_key "alt-f1";
    my $counter = 20;
    while (1) {
        my $selected = check_screen "shutdown_button", 0;
        if (!$selected) {
            wait_screen_change {
                send_key "tab";
            }
        }
        elsif ($selected) {
            assert_screen "shutdown_button", 0;
            send_key "ret";
        }   
        last if ($selected);
        die "looping for too long" unless ($counter--);
    }
}
    
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
