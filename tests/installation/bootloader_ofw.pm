use base "installbasetest";
use strict;

use Time::HiRes qw(sleep);

use testapi;
use registration;

# hint: press shift-f10 trice for highest debug level
sub run() {
    my $self = shift;
    assert_screen "bootloader-ofw", 15;
    if (get_var("UPGRADE")) {
        send_key_until_needlematch 'inst-onupgrade', 'up';
    }
    elsif (get_var("ZDUP")) {
        assert_screen 'inst-onlocal';
    }
    else {
        send_key_until_needlematch 'inst-oninstallation', 'up';
    }
    if (check_var('VIDEOMODE', 'text') || get_var('NETBOOT') || get_var('AUTOYAST')) {
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
        my $args = "";
        # load kernel manually with append
        if (check_var('VIDEOMODE', 'text')) {
            type_string " textmode=1", 15;
        }
        if ( get_var("NETBOOT") && get_var("SUSEMIRROR") ) {
            type_string " install=http://" . get_var("SUSEMIRROR"), 15;
        }
        if ( get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
            my $netsetup = " ifcfg=*=dhcp"; #need this instead of netsetup as default, see bsc#932692
            $netsetup = " ".get_var("NETWORK_INIT_PARAM") if defined get_var("NETWORK_INIT_PARAM"); #e.g netsetup=dhcp,all
            $netsetup = " netsetup=dhcp,all" if defined get_var("USE_NETSETUP"); #netsetup override for sle11
            $args .= $netsetup;
            $args .= " autoyast=" . data_url(get_var("AUTOYAST")) . " ";
        }

        if ( get_var("AUTOUPGRADE")) {
            $args .= " autoupgrade=1";
        }

        type_string $args, 13;
        save_screenshot;
        registration_bootloader_params;
        send_key "ctrl-x";
    }
    save_screenshot;
    send_key "ret";
    if (get_var("ZDUP")) {
        wait_idle(5);
        type_string "boot disk",15;
        save_screenshot
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
