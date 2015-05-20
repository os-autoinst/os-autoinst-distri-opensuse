use strict;
use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    wait_idle;

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 180;
        return;
    }

    mouse_hide();

    if ( get_var("NOAUTOLOGIN") ) {
        my $ret = assert_screen 'displaymanager', 180;
        if ( get_var('DM_NEEDS_USERNAME') ) {
            type_string $username;
        }
        if ( $ret->{needle}->has_tag("sddm") ) {
            # make sure choose plasma5 session
            assert_and_click "sddm-sessions-list";
            assert_and_click "sddm-sessions-plasma5";
            assert_and_click "sddm-password-input";
        }
        else {
            send_key "ret";
            wait_idle;
        }
        type_string "$password";
        send_key "ret";
    }

    assert_screen 'kde-ready', 180;
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1, 'milestone' => 1 };
}

1;

# vim: set sw=4 et:
