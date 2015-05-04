use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    my $self = shift;

    assert_screen "bootloader-ofw", 15;
    $self->key_round('inst-oninstallation', 'up');
    if (check_var('VIDEOMODE', 'text') || get_var('NETBOOT')) {
        # go to cmdline
        send_key "c";
        # load kernel manually with append
        type_string "linux /boot/" . get_var("ARCH") . "/linux";
        if (check_var('VIDEOMODE', 'text')) {
            type_string " textmode=1", 15;
        }
        if ( get_var("NETBOOT") && get_var("SUSEMIRROR") ) {
            type_string " install=http://" . get_var("SUSEMIRROR"), 15;
        }
        if ( get_var("AUTOYAST") ) {
            type_string " netsetup=dhcp,all";
            type_string " autoyast=" . autoinst_url . "/data/" . get_var("AUTOYAST") . " ";
        }
        send_key "ret";
        #load initrd
        type_string "initrd /boot/". get_var("ARCH") . "/initrd";
        send_key "ret";
        #finally boot
        type_string "boot";
        send_key "ret";
    }
    else {
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
