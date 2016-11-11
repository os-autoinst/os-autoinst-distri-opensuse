# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rename livecdreboot, moved grub code in grub_test.pm
#    Livecdreboot test name was unclear, renamed it in to install_and_reboot.
#    The code concerning grub test has moved to new test grub_test.pm
#    Main pm adapted for the new grub_test.pm
#    In first_boot.pm added get_var(boot_into_snapshot) for assert linux-terminal,
#    since after booting on snapshot, only a terminal interface is given, not GUI.
#
#    Issues on progress: 9716,10286,10164
# G-Maintainer: dmaiocchi <dmaiocchi@suse.com>

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
    if (get_var("XEN")) {
        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
    }
    # avoid timeout for booting to HDD
    send_key 'ret';
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
