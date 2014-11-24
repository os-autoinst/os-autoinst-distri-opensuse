use base "x11step";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("xdg-su -c '/sbin/yast2 users'");
    if ($password) { type_password; send_key "ret", 1; }
    assert_screen 'test-yast2_users-1', 30;
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:
