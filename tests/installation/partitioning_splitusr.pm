# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;
    send_key "alt-e", 1;    # Edit
                            # select vda2
    send_key "right";
    send_key "down";        # only works with multiple HDDs
    send_key "right";
    send_key "down";
    send_key "tab";
    send_key "tab";
    send_key "down";

    #send_key "right"; send_key "down"; send_key "down";
    send_key "alt-i", 1;    # Resize
    send_key "alt-u";       # Custom
    type_string "1.5G";
    sleep 2;
    send_key "ret", 1;

    # add /usr
    send_key $cmd{addpart};
    wait_idle 4;
    send_key $cmd{next};
    wait_idle 3;
    for (1 .. 10) {
        send_key "backspace";
    }
    type_string "5.0G";
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-o";    # Operating System
    send_key $cmd{next};
    wait_idle 5;
    send_key "alt-m";        # Mount Point
    type_string "/usr\b";    # Backspace to break bad completion to /usr/local
    assert_screen "partition-splitusr-submitted-usr";
    send_key $cmd{finish};
    assert_screen "partition-splitusr-finished";
    send_key $cmd{accept}, 1;
    send_key "alt-y";        # Quit the warning window
}

1;
# vim: set sw=4 et:
