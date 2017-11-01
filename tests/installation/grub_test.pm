# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle grub menu after reboot
# Tags: poo#9716, poo#10286, poo#10164
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use base "opensusebasetest";
use testapi;
use utils;
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

sub run {
    my ($self) = @_;

    if (get_var('LIVECD')) {
        mouse_hide;
        wait_still_screen;
        assert_screen([qw(generic-desktop-after_installation grub2)]);
        if (match_has_tag('generic-desktop-after_installation')) {
            record_soft_failure 'boo#993885 Kde-Live net installer does not reboot after installation';
            select_console 'install-shell';
            type_string "reboot\n";
            save_screenshot;
            assert_screen 'grub2', 300;
        }
    }

    # due to pre-installation setup, qemu boot order is always booting from CD-ROM
    if (check_var("BOOTFROM", "d")) {
        assert_screen 'inst-bootmenu';
        if (check_var("AUTOUPGRADE") && check_var("PATCH")) {
            assert_screen 'grub2';
        }
        # use firmware boot manager of aarch64 to boot upgraded system
        if (check_var('ARCH', 'aarch64') && get_var('UPGRADE')) {
            send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
            send_key 'ret';
            $self->handle_uefi_boot_disk_workaround;
        }
        else {
            send_key 'ret';
        }
    }
    elsif (get_var('UEFI') && get_var('USBBOOT')) {
        assert_screen 'inst-bootmenu';
        # assuming the cursor is on 'installation' by default and 'boot from
        # harddisk' is above
        send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
        send_key 'ret';
    }

    if (get_var("STORAGE_NG") && get_var("ENCRYPT")) {
        if (check_var('ARCH', 'ppc64le')) {
            # bootloader timeout is disable so hit 'ret' is needed
            assert_screen 'grub2';    # grub appear first in powerpc before the password
            send_key 'ret';
        }
        my @tags = ();
        for (my $disk = 0; $disk < get_var("NUMDISKS", 1); $disk++) {
            push @tags, "grub-encrypted-disk$disk-password-prompt";
        }
        foreach my $tag (@tags) {
            assert_screen($tag, 100);
            type_password;            # enter PW at boot
            send_key "ret";
        }
    }
    unless (get_var("STORAGE_NG") && get_var("ENCRYPT") && check_var('ARCH', 'ppc64le')) {
        workaround_type_encrypted_passphrase;
        # 60 due to rare slowness e.g. multipath poo#11908
        assert_screen "grub2", 60;
        stop_grub_timeout;
    }

    # BSC#997263 - VMware screen resolution defaults to 800x600
    # By default VMware starts with Grub2 in 640x480 mode and then boots the system to
    # 800x600. To avoid that we need to reconfigure Grub's gfxmode and gfxpayload.
    # Permanent - system-wise - solution is in console/consoletest_setup.pm.
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        send_key 'c';
        type_string "gfxmode=1024x768x32; gfxpayload=1024x768x32; terminal_output console; terminal_output gfxterm\n";
        wait_still_screen;
        send_key 'esc';
    }

    boot_into_snapshot if (get_var("BOOT_TO_SNAPSHOT"));
    if (get_var("XEN")) {
        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
    }
    if ((check_var('ARCH', 'aarch64') && check_var('DISTRI', 'sle') && get_var('PLYMOUTH_DEBUG'))
        || get_var('GRUB_KERNEL_OPTION_APPEND'))
    {
        record_soft_failure "Running with plymouth:debug to catch bsc#995310" if get_var('PLYMOUTH_DEBUG');

        send_key 'e';
        # Move to end of kernel boot parameters line
        send_key_until_needlematch "linux-line-selected", "down";
        send_key "end";

        assert_screen "linux-line-matched";
        if (get_var('PLYMOUTH_DEBUG')) {
            # remove "splash=silent quiet showopts"
            for (1 .. 28) { send_key "backspace" }
            type_string 'plymouth:debug';
        }
        type_string " " . get_var('GRUB_KERNEL_OPTION_APPEND') if get_var('GRUB_KERNEL_OPTION_APPEND');

        save_screenshot;
        send_key 'ctrl-x';
    }
    else {
        # avoid timeout for booting to HDD
        send_key 'ret';
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
