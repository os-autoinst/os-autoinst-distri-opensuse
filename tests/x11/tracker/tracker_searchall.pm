# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Tracker search all
# Maintainer: nick wang <nwang@suse.com>

use base "x11test";
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
