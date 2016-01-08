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
        elsif (!get_var("JEOS")) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 5);
        }
    }

    # assume bios+grub+anim already waited in start.sh
    # in grub2 it's tricky to set the screen resolution
    send_key "e";
    if (get_var("JEOS")) {
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
    if (get_var("JEOS")) {
        send_key "up";
    }
    sleep 5;
    for (1 .. 4) { send_key "down"; }
    send_key "end";
    if (get_var("NETBOOT") && get_var("SUSEMIRROR")) {
        assert_screen('no_install_url');
        type_string " install=http://" . get_var("SUSEMIRROR"), 15;
        save_screenshot();
    }
    send_key "spc";

    # if(get_var("PROMO")) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if (check_var('VIDEOMODE', "text")) {
        type_string "textmode=1 ";
    }

    type_string " \\\n";    # changed the line before typing video params
                            # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string "Y2DEBUG=1 ";
    if (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64')) {
        type_string "vga=791 ";
        type_string "video=1024x768-16 ", 13;

        # not needed anymore atm as cirrus has 1024 as default now:
        # https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=121a6a17439b000b9699c3fa876636db20fa4107
        #type_string "drm_kms_helper.edid_firmware=edid/1024x768.bin ";
        assert_screen "inst-video-typed-grub2", 13;
    }

    if (!get_var("NICEVIDEO") && !get_var('JEOS')) {
        type_string "plymouth.ignore-serial-consoles ", 15;    # make plymouth go graphical
        type_string "linuxrc.log=$serialdev ",          4;     #to get linuxrc logs in serial
        type_string " \\\n";                                   # changed the line before typing video params
        type_string "console=$serialdev ",         15;         # to get crash dumps as text
        type_string "console=tty ",                15;         # to get crash dumps as text
        assert_screen "inst-consolesettingstyped", 10;
        my $e = get_var("EXTRABOOTPARAMS");
        if ($e) {
            type_string "$e ", 4;
            save_screenshot;
        }
    }

    #type_string "kiwidebug=1 ";

    my $args = "";
    if (get_var("AUTOYAST")) {
        $args .= " ifcfg=*=dhcp ";
        $args .= "autoyast=" . autoinst_url . "/data/" . get_var("AUTOYAST") . " ";
    }
    type_string $args, 13;
    save_screenshot;

    if (get_var("FIPS")) {
        type_string " fips=1", 13;
        save_screenshot;
    }

    registration_bootloader_params;

    # boot
    send_key "f10";

}

1;
# vim: set sw=4 et:
