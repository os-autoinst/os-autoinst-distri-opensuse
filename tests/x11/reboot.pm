use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "grub2", 100;    # wait until reboot
    if ( get_var("ENCRYPT") ) {
        $self->pass_disk_encrypt_check;
    }

    # 570_xfce_login_after_reboot
    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        assert_screen 'displaymanager', 200;
        wait_idle;

        # log in
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username. "\n";
        }
        type_string $password. "\n";
    }

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);
}

sub test_flags() {
    return { 'milestone' => 1 };
}
1;

# vim: set sw=4 et:
