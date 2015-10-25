use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    wait_idle;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'sddm_reboot_option_btn';
    # sometimes not reliable, since if clicked the background
    # color of button should changed, thus check and click again
    if (check_screen("sddm_reboot_option_btn", 1)) {
        assert_and_click 'sddm_reboot_option_btn';
    }
    assert_and_click 'sddm_reboot_btn';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        type_password;
        send_key "ret";
    }
}

sub test_flags() {
    return {important => 1};
}
1;

# vim: set sw=4 et:
