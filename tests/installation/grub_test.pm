# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "basetest";
use testapi;
use utils;

sub run() {
    my $self = shift;
    if (get_var('ENCRYPT') && check_var('ARCH', 'ppc64le')) {
        record_soft_failure 'workaround https://fate.suse.com/320901';
        unlock_if_encrypted;
    }
    assert_screen "grub2";
    # prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then
    send_key 'up';
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
