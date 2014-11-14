use base "installbasetest";
use strict;
use bmwqemu;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    if (check_screen "bootloader-ofw", 15) {
        send_key "up";
        send_key "up";
        send_key "up";
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
