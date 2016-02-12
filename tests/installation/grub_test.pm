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
    # prevent grub2 timeout
    send_key 'esc';
    if (get_var("BOOT_TO_SNAPSHOT")) {
        send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
        send_key 'ret';
        assert_screen("boot-menu-snapshot-list");
        send_key 'ret';
        assert_screen("boot-menu-snapshot-bootmenu");
        send_key 'down', 1;
        save_screenshot;
    }
    if (get_var("XEN")) {
        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
    }
    # avoid timeout for booting to HDD
    send_key 'ret';
}
1;
# vim: set sw=4 et:
