# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tracker search all
# Maintainer: nick wang <nwang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    x11_start_program("tracker-needle", target_match => 'tracker-needle-launched');
    if (is_sle('<12-SP2')) {
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'right' };
        wait_screen_change { send_key 'ret' };
        #switch to search input field
        for (1 .. 4) { send_key "right" }
    }
    type_string "newfile";
    assert_screen 'tracker-search-result';
    send_key "alt-f4";
}

1;
