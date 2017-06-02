# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: dmaiocchi <dmaiocchi@suse.com>

use strict;
use base "basetest";
use testapi;
use bootloader_setup 'stop_grub_timeout';

sub run() {
    select_console 'root-console';
    type_string "reboot\n";
    reset_consoles;
    assert_screen 'grub2', 200;
    stop_grub_timeout;

    send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
    send_key 'ret';
    # find out the before migration snapshot
    send_key_until_needlematch("snap-before-update", 'down', 40, 5) if (get_var("UPGRADE") || get_var("ZDUP"));
    send_key_until_needlematch("snap-before-migration", 'down', 40, 5) if (get_var("MIGRATION_ROLLBACK"));
    send_key "ret";
    # avoid timeout for booting to HDD
    send_key 'ret';
}
sub test_flags() {
    return {fatal => 1};
}
1;
# vim: set sw=4 et:
