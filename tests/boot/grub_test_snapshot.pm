# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Enable Snapper-Rollback on HDD special Image.
#    Enable test-workflow on Main
# G-Maintainer: dmaiocchi <dmaiocchi@suse.com>

use strict;
use base "basetest";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "grub2";
    # prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then
    send_key 'up';
    if (get_var("BOOT_TO_SNAPSHOT")) {
        send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
        send_key 'ret';
        # find out the before migration snapshot
        send_key_until_needlematch("snap-before-update",    'down', 40, 5) if (get_var("UPGRADE"));
        send_key_until_needlematch("snap-before-migration", 'down', 40, 5) if (get_var("MIGRATION_ROLLBACK"));
        send_key "ret";
        # bsc#956046  check if we are in first menu-entry, or not
        if (check_screen("boot-menu-snapshot-bootmenu")) {
            record_soft_failure 'bsc#956046';
            send_key 'down', 1;
            save_screenshot;
        }
        send_key 'ret';
    }
    # avoid timeout for booting to HDD
    send_key 'ret';
}
sub test_flags() {
    return {fatal => 1};
}
1;
# vim: set sw=4 et:
