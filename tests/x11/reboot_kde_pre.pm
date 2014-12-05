use base "x11test";
use testapi;

sub run() {
    my $self = shift;

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

# override post work, we don't need to check
# desktop screenshot at the end
sub post_run_hook {
    my ($self) = @_;
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
