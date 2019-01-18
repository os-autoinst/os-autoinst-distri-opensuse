# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Evince find feature
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436022

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    x11_start_program("evince " . autoinst_url . "/data/x11/test.pdf", valid => 0);

    send_key "ctrl-f";    # show search toolbar
    assert_screen 'evince-search-toolbar', 5;

    type_string 'To search for';
    assert_screen 'evince-search-1stresult', 10;

    for (1 .. 2) {
        send_key "ctrl-g";    # go to next result
    }
    assert_screen 'evince-search-3rdresult', 5;

    for (1 .. 2) {
        send_key "ctrl-shift-g";    # go to previous result
    }
    assert_screen 'evince-search-1stresult', 5;

    wait_screen_change { send_key "esc" };
    send_key "ctrl-w";
}

1;
