# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot on UEFI systems with configuration of boot parameters
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;

use Time::HiRes 'sleep';

use testapi;
use lockapi;
use bootloader_setup;
use registration;
use utils;

# hint: press shift-f10 trice for highest debug level
sub run {
    if (get_var("IPXE")) {
        sleep 60;
        return;
    }

    if (get_var('DUALBOOT')) {
        tianocore_select_bootloader;
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 5, 5);
        send_key "ret";
    }

    # Skip to load bootloader in test of online migration on aarch64
    # Handle aarch64 image boot by wait_boot called in setup_online_migration
    if (get_var('ONLINE_MIGRATION') && check_var('ARCH', 'aarch64')) {
        return;
    }

    # aarch64 firmware 'tianocore' can take longer to load
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 30 : 15;
    $self->wait_for_boot_menu(bootloader_time => $bootloader_timeout);
    if (get_var("QEMUVGA") && get_var("QEMUVGA") ne "cirrus") {
        sleep 5;
    }
    if (get_var("ZDUP")) {
        # uefi bootloader has no "boot from harddisk" option. So we
        # have to just reboot here
        eject_cd;
        power('reset');
        assert_screen("grub2");
        return;
    }

    if (get_var("UPGRADE")) {
        # random magic numbers
        send_key_until_needlematch('inst-onupgrade', 'down', 10, 5);
    }
    else {
        if (get_var("PROMO") || get_var('LIVETEST')) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
        }
        elsif (!is_jeos && !is_caasp('VMX')) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 5);
        }
    }

    uefi_bootmenu_params;
    bootmenu_default_params;
    specific_bootmenu_params unless is_caasp || is_jeos;
    specific_caasp_params;

    # JeOS and CaaSP are never deployed with Linuxrc involved,
    # so 'regurl' does not apply there.
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless (is_jeos or is_caasp);

    # if a support_server is used, we need to wait for him to finish its initialization
    # and we need to do it *before* starting the OS, as a DHCP request can happen too early
    if (check_var('USE_SUPPORT_SERVER', 1)) {
        diag "Waiting for support server to complete setup...";

        # we use mutex to do this
        mutex_lock('support_server_ready');
        mutex_unlock('support_server_ready');
    }

    # boot
    send_key "f10";
}

1;
# vim: set sw=4 et:
