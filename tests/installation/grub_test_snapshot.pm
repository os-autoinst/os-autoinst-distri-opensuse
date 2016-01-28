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
use base "y2logsstep";
use testapi;
use bmwqemu ();

sub run() {
    up_and_down();
    assert_screen "grub2";
    send_key "esc";
    send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
    send_key 'ret';
    assert_screen("boot-menu-snapshot-list");
    # we assume that we have 2 snapshots. so for upgrade testing we are going
    #  before_upgrade snapshot, the second one. otherwise, just boot into first snapshot
    if (get_var('UPGRADE')) {
        send_key 'down';
        save_screenshot;
    }
    send_key 'ret';
    save_screenshot;
    send_key "ret";
}

sub up_and_down() {
    my $retries = 20;    # empiric value just to be on the safe side
    for (my $i = 0; $i <= $retries; $i++) {
        send_key 'down';
        send_key 'up';
    }
}
1;
# vim: set sw=4 et:
