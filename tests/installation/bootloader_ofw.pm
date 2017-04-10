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
use registration;
use utils;

# hint: press shift-f10 trice for highest debug level
sub run() {
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
        || get_var('EXTRABOOTPARAMS'))
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
            if (get_var("NETBOOT")) {
                if (get_var("SUSEMIRROR")) {
                    $args .= ' install=http://' . get_var("SUSEMIRROR");
                }
                else {
                    $args .= ' kernel=1 insecure=1';
                }
            }
            if (get_var("DUD")) {
                my $dud = get_var("DUD");
                if ($dud =~ /http:\/\/|https:\/\/|ftp:\/\//) {
                    $args .= " dud=$dud insecure=1";
                }
                else {
                    $args .= " dud=" . data_url($dud) . " insecure=1";
                }
            }
            if (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
                my $netsetup = " ifcfg=*=dhcp";    #need this instead of netsetup as default, see bsc#932692
                $netsetup = " " . get_var("NETWORK_INIT_PARAM")
                  if defined get_var("NETWORK_INIT_PARAM");    #e.g netsetup=dhcp,all
                $args .= $netsetup;
                $args .= " autoyast=" . data_url(get_var("AUTOYAST")) . " ";
            }

            if (get_var("AUTOUPGRADE")) {
                $args .= " autoupgrade=1";
            }

            type_string_slow $args;

            if (get_var("FIPS")) {
                type_string_slow ' fips=1';
                save_screenshot;
            }

            if (my $e = get_var("EXTRABOOTPARAMS")) {
                type_string_very_slow " $e";
                save_screenshot;
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
