# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: evince
# Summary: Evince: View
# - Launch evince and open test.pdf from datadir
# - Send F11 (full screen) and check
# - Send ESC to exit fullscreen
# - Send F5 (presentation mode) and check
# - Send ESC to exit presentation mode
# - Close evince
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
# Tags: tc#1436026

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    x11_start_program("evince " . autoinst_url . "/data/x11/test.pdf", valid => 0);

    send_key "f11";    # fullscreen mode
    assert_screen 'evince-fullscreen-mode', 5;
    send_key "esc";

    send_key "f5";    # presentation mode
    assert_screen 'evince-presentation-mode', 5;
    send_key "esc";

    send_key "ctrl-w";
}

1;
