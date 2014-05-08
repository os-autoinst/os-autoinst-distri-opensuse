use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    x11_start_program("xdg-su -c '/sbin/yast2 users'");
    if ($password) { sendpassword; send_key "ret", 1; }
    $self->check_screen;
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:
