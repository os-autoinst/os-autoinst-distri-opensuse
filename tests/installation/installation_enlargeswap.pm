# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add test to check enlarge swap for suspend
# G-Maintainer: Zaoliang Luo <zluo@e13.suse.de>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    send_key 'alt-d';    # open proposal settings
    if (!check_screen 'enlarge-enabled', 5) {
        assert_screen 'enlarge-disabled';
        send_key 'alt-s';
    }
    assert_screen 'enlarge-enabled';
    send_key 'alt-o';    # close proposal settings
}
1;

# vim: set sw=4 et:
