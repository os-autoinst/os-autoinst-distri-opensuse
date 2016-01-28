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
    # boot_to_snapshot is tested in other file. only xen needs testing.
    if (get_var("XEN")) {
        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
    }
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
