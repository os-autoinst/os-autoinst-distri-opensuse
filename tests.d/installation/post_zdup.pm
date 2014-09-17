use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    # reboot after dup
    send_key "ctrl-alt-delete";
    assert_screen "tty1-selected", 50;
}

1;
# vim: set sw=4 et:
