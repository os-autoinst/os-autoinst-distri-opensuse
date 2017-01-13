# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: New test to take the first disk
#    Otherwise the partitioning proposal will use a free disk, which makes
#    rebooting a game of chance on real hardware
# G-Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {

    # create partitioning
    send_key $cmd{createpartsetup};
    assert_screen 'prepare-hard-disk';

    assert_screen_change {
        send_key 'alt-1';
    };
    send_key 'alt-n';

    assert_screen 'use-entire-disk';
    assert_screen_change {
        send_key 'alt-e';
    };
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
