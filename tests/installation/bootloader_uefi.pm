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
sub run() {
    if (get_var("IPXE")) {
        sleep 60;
        return;
    }

    if (get_var('DUALBOOT')) {
        tianocore_select_bootloader;
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 5, 5);
        send_key "ret";
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

    # assume bios+grub+anim already waited in start.sh
    # in grub2 it's tricky to set the screen resolution
    send_key "e";
    if (is_jeos) {
        for (1 .. 3) { send_key "down"; }
        send_key "end";
        # delete "800x600"
        for (1 .. 7) { send_key "backspace"; }
    }
    else {
        for (1 .. 2) { send_key "down"; }
        send_key "end";
        # delete "keep" word
        for (1 .. 4) { send_key "backspace"; }
    }
    # hardcoded the value of gfxpayload to 1024x768
    type_string "1024x768";
    assert_screen "gfxpayload_changed", 10;
    # back to the entry position
    send_key "home";
    for (1 .. 2) { send_key "up"; }
    if (is_jeos) {
        send_key "up";
    }
    sleep 5;
    for (1 .. 4) { send_key "down"; }
    send_key "end";

    if (get_var("NETBOOT")) {
        type_string_slow " install=" . get_netboot_mirror;
        save_screenshot();
    }
    send_key "spc";

    # if(get_var("PROMO")) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if (check_var('VIDEOMODE', "text")) {
        type_string_slow "textmode=1 ";
    }

    type_string " \\\n";    # changed the line before typing video params
    bootmenu_default_params;
    specific_bootmenu_params;

    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);

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
