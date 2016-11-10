# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle grub menu after installer reboots
# Maintainer: mkravec <mkravec@suse.com>

use strict;
use base "basetest";
use testapi;
use utils;

sub run() {
    my $self = shift;

    if (get_var('LIVECD')) {
        mouse_hide;
        wait_still_screen;
        assert_screen([qw/generic-desktop-after_installation grub2/]);
        if (match_has_tag('generic-desktop-after_installation')) {
            record_soft_failure 'boo#993885 Kde-Live net installer does not reboot after installation';
            select_console 'install-shell';
            wait_still_screen;
            type_string "reboot\n";
            save_screenshot;
            assert_screen 'grub2', 300;
        }
    }

    # due to pre-installation setup, qemu boot order is always booting from CD-ROM
    if (check_var("BOOTFROM", "d")) {
        assert_screen 'inst-bootmenu';
        send_key 'ret';
    }
    workaround_type_encrypted_passphrase;
    # 60 due to rare slowness e.g. multipath poo#11908
    assert_screen "grub2", 60;
    # prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then
    send_key 'up';

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

    if (get_var("BOOT_TO_SNAPSHOT")) {
        send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
        send_key 'ret';
        assert_screen("boot-menu-snapshot-list");
        # in upgrade/migration scenario, we want to boot from snapshot 1 before migration.
        if (get_var("UPGRADE")) {
            send_key 'down';
            save_screenshot;
        }
        send_key 'ret';
        # bsc#956046  check if we are in first menu-entry, or not
        if (check_screen("boot-menu-snapshot-bootmenu")) {
            record_soft_failure 'bsc#956046';
            send_key 'down', 1;
            save_screenshot;
        }
        send_key 'ret';
    }
    elsif (get_var("XEN")) {
        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
    }
    elsif (check_var('ARCH', 'x86_64') && check_var('DISTRI', 'sle')) {
        record_soft_failure "bsc#995310 - Gnome fails to start";
        send_key 'e';
        # Move to end of kernel boot parameters line
        for (1 .. 14) { send_key "down" }
        send_key "end";
        # remove "splash=silent quiet showopts"
        for (1 .. 28) { send_key "backspace" }
        type_string 'plymouth:debug';
        save_screenshot;
        send_key 'ctrl-x';
    }
    # avoid timeout for booting to HDD
    send_key 'ret';
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
