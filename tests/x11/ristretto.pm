# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ristretto
# Summary: test ristretto and open the default wallpaper
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use testapi;

sub run {
    x11_start_program("ristretto /usr/share/wallpapers/xfce/default.wallpaper", valid => 0);
    wait_screen_change { send_key "ctrl-m" };
    assert_screen 'test-ristretto-1';
    send_key "alt-f4";
}

1;
