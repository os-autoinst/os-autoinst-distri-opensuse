# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle PowerPC specific boot process
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;

use Time::HiRes 'sleep';

use testapi;
use bootloader_setup;
use registration;
use utils;

# hint: press shift-f10 trice for highest debug level
sub run {
    assert_screen "bootloader", 15;
    if (get_var("UPGRADE") && get_var('PATCHED_SYSTEM')) {
        send_key_until_needlematch 'inst-onupgrade', 'up';
    }
    elsif (get_var("ZDUP") || get_var("ONLINE_MIGRATION") || get_var('PATCH')) {
        assert_screen 'inst-onlocal';
    }
    else {
        send_key_until_needlematch 'inst-oninstallation', 'up';
    }
    if (   check_var('VIDEOMODE', 'text')
        || get_var('NETBOOT')
        || get_var('AUTOYAST')
        || get_var('SCC_URL')
        || get_var('DUD')
        || get_var('EXTRABOOTPARAMS')
        || get_var('FIPS')
        || get_var('AUTOUPGRADE')
        || get_var('INSTALLER_SELF_UPDATE')
        || get_var('INSTALLER_NO_SELF_UPDATE')
        || get_var('IBFT'))
    {
        if (get_var("ZDUP") || get_var("ONLINE_MIGRATION") || get_var('PATCH')) {
            send_key "down";
            send_key "ret";
        }
        else {
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
                $args .= " textmode=1";
            }
            if (get_var("NETBOOT") && get_var("SUSEMIRROR")) {
                $args .= ' install=http://' . get_var("SUSEMIRROR");
            }

            type_string_very_slow $args;
            save_screenshot;

            specific_bootmenu_params;

            if (my $e = get_var("EXTRABOOTPARAMS")) {
                type_string_very_slow " $e";
                save_screenshot;
            }

            registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);
            send_key "ctrl-x";
        }
    }
    save_screenshot;
    send_key "ret";
}

1;
# vim: set sw=4 et:
