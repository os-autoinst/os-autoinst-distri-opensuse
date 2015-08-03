use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    my $self = shift;

    assert_screen "bootloader-ofw", 15;
    if (get_var("UPGRADE")) {
        send_key_until_needlematch 'inst-onupgrade', 'up';
    }
    else {
        send_key_until_needlematch 'inst-oninstallation', 'up';
    }
    if (check_var('VIDEOMODE', 'text') || get_var('NETBOOT')) {
        # edit menu
        send_key "e";
        #wait until we get to grub edit
        wait_idle(5);
        #go down to kernel entry
        send_key "down";
        send_key "down";
        send_key "down";
        send_key "end";
        wait_idle(5);
        # load kernel manually with append
        if (check_var('VIDEOMODE', 'text')) {
            type_string " textmode=1", 15;
        }
        if ( get_var("NETBOOT") && get_var("SUSEMIRROR") ) {
            type_string " install=http://" . get_var("SUSEMIRROR"), 15;
        }
        if ( get_var("AUTOYAST") ) {
            type_string " netsetup=dhcp,all", 15;
            type_string " autoyast=" . autoinst_url . "/data/" . get_var("AUTOYAST") . " ", 15;
        }
        save_screenshot;
        send_key "ctrl-x";
    }
    save_screenshot;
    send_key "ret";
}

1;
# vim: set sw=4 et:
