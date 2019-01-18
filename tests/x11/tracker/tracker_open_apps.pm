# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tracker: search application in tracker and open it
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436342

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    x11_start_program('tracker-needle');
    type_string "cheese";
    assert_screen 'tracker-search-cheese';
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'down' };
    send_key "ret";
    assert_screen 'cheese-launched';
    wait_screen_change { send_key 'alt-f4' };
    send_key "alt-f4";
}

1;
