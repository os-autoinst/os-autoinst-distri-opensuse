# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use testapi;

# the test won't work atm
sub run() {
    my $homekey = check_var('VIDEOMODE', "text") ? "alt-p" : "alt-h";
    send_key 'alt-d';
    $closedialog = 1;
    $homekey     = 'alt-p';
    assert_screen "partition-proposals-window", 5;
    send_key $homekey;
    for (1 .. 3) {
        if (!check_screen "disabledhome", 8) {
            send_key $homekey;
        }
        else {
            last;
        }
    }
    assert_screen "disabledhome", 5;
    if ($closedialog) {
        send_key 'alt-o';
        $closedialog = 0;
    }
    wait_idle 5;
}

1;
# vim: set sw=4 et:
