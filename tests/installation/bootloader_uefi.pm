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
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 25 : 15;
    assert_screen([qw(bootloader-shim-import-prompt bootloader-grub2)], $bootloader_timeout);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
        assert_screen "bootloader-grub2", $bootloader_timeout;
    }
    if (get_var("QEMUVGA") && get_var("QEMUVGA") ne "cirrus") {
        sleep 5;
    }
    if (is_jeos) {
        # tell grub to use the correct gfx mode (bsc#963952)
        send_key 'c';
        type_string "gfxmode=1024x768; terminal_output console; terminal_output gfxterm\n";
        sleep 2;
        send_key 'esc';
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
        elsif (!is_jeos && !is_casp('VMX')) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 5);
        }
    }

    uefi_bootmenu_params;
    bootmenu_default_params;
    specific_bootmenu_params;
    specific_caasp_params;

    # JeOS and CaaSP are never deployed with Linuxrc involved,
    # so 'regurl' does not apply there.
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless (is_jeos or is_casp);

    # boot
    send_key "f10";

    # This is a workaround for xfreerdp connected to Windows Server 2008 R2.
    # See issue https://github.com/FreeRDP/FreeRDP/issues/3362.
    # xfreerdp is started in window-mode (i.e. non-fullscreen), now when
    # all resolution changes (by Hyper-V BIOS, Grub) were done we should
    # switch to fullscreen so needles match.
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        send_key("ctrl-alt-ret");
    }
}

1;
# vim: set sw=4 et:
