use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    if ( !check_screen('sddm', 10) ) {
        # make sure back to login screen
        send_key "ctrl-alt-delete";    # logout dialog
        assert_screen 'logoutdialog', 15;
        assert_and_click 'sddm_logout_btn';
    }

    mouse_hide();

    # log in
    assert_screen 'displaymanager', 20;
    # make sure choose plasma5 session
    assert_and_click "sddm-sessions-list";
    assert_and_click "sddm-sessions-plasma5";
    assert_and_click "sddm-password-input";

    type_string "$password";
    send_key "ret";

    assert_screen 'generic-desktop', 20;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
