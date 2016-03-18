# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;

use Time::HiRes qw(sleep);

use testapi;
use registration;
use utils;

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
    if (check_var('VIDEOMODE', 'text') || get_var('NETBOOT') || get_var('AUTOYAST') || get_var('SCC_URL')) {
        if (get_var("ZDUP")) {
            send_key "down";
            send_key "ret";
        }
        else {
            # edit menu
            send_key "e";
            #wait until we get to grub edit
            wait_idle(5);
            #go down to kernel entry
            for (1 .. 3) { send_key "down"; }
            send_key "end";
            wait_idle(5);

            # load kernel manually with append
            if (check_var('VIDEOMODE', 'text')) {
                $self->set_textmode;
            }
            if (get_var("NETBOOT")) {
                $self->set_netboot_mirror;
            }
            if (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
                $self->set_network;
                $self->set_autoyast;
            }

            if (get_var("AUTOUPGRADE")) {
                $self->set_autoupgrade;
            }

            if (get_var("FIPS")) {
                $self->set_fips;
            }
            save_screenshot;

            registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
            send_key "ctrl-x";
        }
    }
    save_screenshot;
    send_key "ret";
}

1;
# vim: set sw=4 et:
