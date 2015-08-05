use base "x11test";
use strict;
use testapi;

# case 1436143-test nautilus open ftp

sub run() {
    my $self = shift;

    x11_start_program("nautilus");
    send_key "ctrl-l", 1;
    type_string "ftp://ftp.suse.com\n";
    assert_screen "nautilus-ftp-login", 5;
    send_key "ret";
    assert_screen 'nautilus-ftp-suse-com', 20;

    send_key "shift-f10";
    assert_screen 'nautilus-ftp-rightkey-menu', 3;
    send_key "u";           #umount the ftp

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
