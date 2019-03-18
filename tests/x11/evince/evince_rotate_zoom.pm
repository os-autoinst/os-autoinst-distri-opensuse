# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Evince: Rotate and Zoom
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436024

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    x11_start_program("evince " . autoinst_url . "/data/x11/test.pdf", valid => 0);

    send_key "ctrl-left";    # rotate left
    assert_screen 'evince-rotate-left', 5;
    send_key "ctrl-right";
    send_key "ctrl-right";    # rotate right
    assert_screen 'evince-rotate-right', 5;
    send_key "ctrl-left";

    send_key "ctrl-+";        # zoom in
    assert_screen 'evince-zoom-in', 5;

    for (1 .. 2) {
        send_key "ctrl-minus";    # zoom out
    }
    assert_screen 'evince-zoom-out', 5;
    send_key "ctrl-+";

    send_key "ctrl-w";
}

1;
