use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    if ( get_var("OFW") ) {
        assert_screen "bootloader-ofw", 100;
    }
    else {
        assert_screen "grub2", 100;    # wait until reboot
    }
    if ( get_var("ENCRYPT") ) {
        $self->pass_disk_encrypt_check;
    }

    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        my $ret = assert_screen 'displaymanager', 200;
        wait_idle;
        if ( $ret->{needle}->has_tag("sddm") ) {
            # make sure choose plasma5 session
            assert_and_click "sddm-sessions-list";
            assert_and_click "sddm-sessions-plasma5";
            assert_and_click "sddm-password-input";
            type_string "$password";
            send_key "ret";
        }
        else {
            # log in
            type_string $username. "\n";
            assert_screen "dm-password-input", 10;
            type_string $password. "\n";
        }
    }

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);
}

sub test_flags() {
    return { milestone => 1, important => 1 };
}
1;

# vim: set sw=4 et:
