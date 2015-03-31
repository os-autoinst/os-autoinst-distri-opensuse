use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    assert_screen "bootloader-ofw", 15;
    send_key "up";
    send_key "up";
    send_key "up";
    if (check_var('VIDEOMODE', 'text') || get_var('NETBOOT')) {
        send_key "e";
        send_key "down";
        send_key "down";
        send_key "down";
        send_key "end";
        if (check_var('VIDEOMODE', 'text')) {
            type_string " textmode=1", 15;
        }
        send_key "spc";
        if ( get_var("NETBOOT") && get_var("SUSEMIRROR") ) {
            type_string " install=http://" . get_var("SUSEMIRROR"), 15;
        }
        send_key "ctrl-x";
    }
    else {
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
