use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    assert_screen "bootloader-ofw-yaboot", 15;
    if (check_var('VIDEOMODE', 'text')) {
        type_string "install textmode=1", 15;
    }
    send_key "ret";
}

1;
# vim: set sw=4 et:
