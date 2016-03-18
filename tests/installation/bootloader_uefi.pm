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
    my ($self) = @_;

    if (get_var("IPXE")) {
        sleep 60;
        return;
    }
    check_screen([qw/bootloader-shim-import-prompt bootloader-grub2/], 15);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
    assert_screen "bootloader-grub2", 15;
    if (get_var("QEMUVGA") && get_var("QEMUVGA") ne "cirrus") {
        sleep 5;
    }
    if (is_jeos) {
        # tell grub to use the correct gfx mode (bnc#963952)
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
        elsif (!is_jeos) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 5);
        }
    }

    # Assume bios+grub+anim already waited in start.sh
    send_key "e";
    my ($x, $y) = is_jeos ? (3, 7) : (2, 4);

    # Move to gfxpayload line
    for (1 .. $x) { send_key "down"; }
    send_key "end";
    # Delete "800x600 | keep"
    for (1 .. $y) { send_key "backspace"; }
    # hardcoded the value of gfxpayload to 1024x768
    type_string "1024x768";
    assert_screen "gfxpayload_changed", 10;

    # Move to linux line
    for (1 .. 4 - $x) { send_key "down"; }
    send_key "end";

    if (get_var("NETBOOT")) {
        $self->set_netboot_mirror;
        $self->set_netboot_proxy if get_var("HTTPPROXY");
        save_screenshot();
    }

    # if(get_var("PROMO")) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if (check_var('VIDEOMODE', "text")) {
        $self->set_textmode;
    }

    type_string " \\\n";    # changed the line before typing video params
                            # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string_slow 'Y2DEBUG=1 ';
    if (!is_jeos && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
        type_string_slow 'vga=791 ';
        type_string_slow 'video=1024x768-16 ';

        # not needed anymore atm as cirrus has 1024 as default now:
        # https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=121a6a17439b000b9699c3fa876636db20fa4107
        #type_string "drm_kms_helper.edid_firmware=edid/1024x768.bin ";
        assert_screen "inst-video-typed-grub2";
    }

    if (!get_var("NICEVIDEO") && !is_jeos) {
        type_string_slow "plymouth.ignore-serial-consoles ";    # make plymouth go graphical
        type_string_slow "linuxrc.log=$serialdev ";             # to get linuxrc logs in serial
        type_string " \\\n";                                    # changed the line before typing video params
        type_string_slow "console=$serialdev ";                 # to get crash dumps as text
        type_string_slow "console=tty ";                        # to get crash dumps as text
        assert_screen "inst-consolesettingstyped", 10;
    }
    if (get_var("EXTRABOOTPARAMS")) {
        $self->set_extra_params;
    }

    #type_string_slow 'kiwidebug=1 ';

    if (get_var("AUTOYAST")) {
        $self->set_network;
        $self->set_autoyast;
    }

    if (get_var("FIPS")) {
        $self->set_fips;
    }
    save_screenshot;

    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);

    # boot
    send_key "f10";
}

1;
# vim: set sw=4 et:
