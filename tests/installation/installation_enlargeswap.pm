# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add test to check enlarge swap for suspend
# Maintainer: Zaoliang Luo <zluo@e13.suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    send_key 'alt-d';    # open proposal settings
    if (!check_screen 'enlarge-enabled', 5) {
        assert_screen 'enlarge-disabled';
        send_key 'alt-s';
    }
    assert_screen 'enlarge-enabled';
    send_key 'alt-o';    # close proposal settings
}
1;

