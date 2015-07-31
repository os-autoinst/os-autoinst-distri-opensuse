use base "basetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    assert_screen "inst-bootmenu", 30;
    sleep 2;
    send_key "ret";    # boot

    assert_screen "grub2", 15;
    sleep 1;
    send_key "ret";

    mouse_hide(1);

    if ( get_var("NOAUTOLOGIN") ) {
        my $ret = assert_screen 'displaymanager', 200;
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

    assert_screen "generic-desktop", 200;
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
