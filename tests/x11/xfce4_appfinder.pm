# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test xfce4-appfinder, auto-completion and starting xfce4-about
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use testapi;
use version_utils qw(is_tumbleweed is_leap);
use x11utils 'desktop_runner_hotkey';


sub run {
    wait_screen_change { send_key desktop_runner_hotkey };
    send_key "down";
    # In XFCE 4.14+, a dynamic search is performed - poo#56111
    if (is_tumbleweed || is_leap(">=15.2")) {
        type_string "about xfce";
    } else {
        enter_cmd "about";
    }
    assert_screen 'test-xfce4_appfinder-1';
    send_key "ret";
    assert_screen 'test-xfce4_appfinder-2';
    send_key "alt-f4";
}

1;
