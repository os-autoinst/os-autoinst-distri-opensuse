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

sub run() {
    my $self = shift;
    assert_screen "grub2";
    # prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then

    send_key 'up';
    if (get_var("BOOT_TO_SNAPSHOT")) {
        send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
        send_key 'ret';
        # find out the before migration snapshot
        send_key 'end';
        send_key_until_needlematch("snap-before-update",    'up', 40, 5) if (get_var("UPGRADE"));
        send_key_until_needlematch("snap-before-migration", 'up', 40, 5) if (get_var("MIGRATION_ROLLBACK"));
        send_key "ret";
        send_key 'up';    #stop grub

        # bsc#956046  check if we are in first menu-entry, or not
        if (check_screen("boot-menu-snapshot-bootmenu")) {
            record_soft_failure 'bsc#956046';
            send_key 'down', 1;
            save_screenshot;
        }

        send_key 'e';
        save_screenshot;
        send_key_until_needlematch 'grub-linux-line', 'down', 15;
        send_key 'end';
        send_key 'spc';
        type_string '3';
        wait_still_screen(2);
        send_key 'ctrl-x';
    }
    save_screenshot;
}

sub test_flags() {
    return {fatal => 1};
}
1;
# vim: set sw=4 et:
