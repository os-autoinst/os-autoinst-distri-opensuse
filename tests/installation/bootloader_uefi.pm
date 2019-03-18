# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot on UEFI systems with configuration of boot parameters
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;
use warnings;

use Time::HiRes 'sleep';

use testapi;
use lockapi 'mutex_wait';
use bootloader_setup;
use registration;
use utils;
use version_utils qw(is_jeos is_caasp);

# hint: press shift-f10 trice for highest debug level
sub run {
    my ($self) = @_;

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
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 45 : 15;
    assert_screen([qw(bootloader-shim-import-prompt bootloader-grub2)], $bootloader_timeout);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
        assert_screen "bootloader-grub2", $bootloader_timeout;
    }
    if (get_var("QEMUVGA") && get_var("QEMUVGA") ne "cirrus") {
        sleep 5;
    }
    if (get_var("ZDUP")) {
        # 'eject_cd' is broken ATM (at least on aarch64), so select HDD from menu - poo#47303
        # Check we are booting the ISO
        assert_screen 'inst-bootmenu';
        # Select boot from HDD
        send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
        send_key 'ret';
        # use firmware boot manager of aarch64 to boot HDD
        $self->handle_uefi_boot_disk_workaround if (check_var('ARCH', 'aarch64'));
        assert_screen("grub2");
        return;
    }

    if (get_var("UPGRADE")) {
        # random magic numbers
        send_key_until_needlematch('inst-onupgrade', 'down', 10, 3);
    }
    else {
        if (get_var("PROMO") || get_var('LIVETEST') || get_var('LIVECD')) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 3);
        }
        elsif (!is_jeos && !is_caasp('VMX')) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 3);
        }
    }

    uefi_bootmenu_params;
    bootmenu_default_params;
    specific_bootmenu_params unless is_caasp || is_jeos;
    specific_caasp_params;

    # JeOS and CaaSP are never deployed with Linuxrc involved,
    # so 'regurl' does not apply there.
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless (is_jeos or is_caasp);

    # boot
    mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
    send_key "f10";
}

1;
