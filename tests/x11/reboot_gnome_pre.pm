use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    wait_idle;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        sleep 3;
        type_password;
        sleep 3;
        send_key "ret";

        if (check_screen('please-try-again', 3)) {
            record_soft_failure;
            type_password;
            send_key "ret";
        }
    }
}

sub test_flags() {
    return { 'important' => 1 };
}
1;

# vim: set sw=4 et:
