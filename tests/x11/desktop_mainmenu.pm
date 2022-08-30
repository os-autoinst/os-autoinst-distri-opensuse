# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: lxde xfce
# Summary: Test that desktop main menu shows up (support multiple DEs/WMs)
# - open main menu and check that it matches the needle
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_leap);


sub run {
    # some desktops need some time to accept user input
    sleep 10;
    if (check_var("DESKTOP", "lxde")) {
        # or Super_L or Windows key
        x11_start_program('lxpanelctl menu', target_match => 'test-desktop_mainmenu-1');
    }
    elsif ((check_var("DESKTOP", "gnome") || check_var("DESKTOP", "xfce")) && !is_leap("<15.3")) {
        send_key "super";
    }
    elsif (check_var("DESKTOP", "xfce")) {
        mouse_set(0, 0);
        sleep 1;
        assert_screen_change { send_key "ctrl-esc" };    # open menu
        send_key "up";    # go into Applications submenu
        mouse_hide(1);
    }
    else {
        send_key_until_needlematch 'test-desktop_mainmenu-1', 'alt-f1', 6, 10;
    }
    assert_screen 'test-desktop_mainmenu-1', 20;

    send_key "esc";
}

sub ocr_checklist {
    [

        {
            screenshot => 1,
            x => 30,
            y => 30,
            xs => 200,
            ys => 250,
            pattern => "(?si:ccessories.*Internet.*ffice.*Universal .ccess)",
            result => "OK"
        },    # gnome
        {
            screenshot => 1,
            x => 20,
            y => 5,
            xs => 200,
            ys => 250,
            pattern => "(?si:reate .auncher.*reate..?older.*pen Terminal Here.*rrange Des.top .cons)",
            result => "OK"
        },    # xfce
        {
            screenshot => 1,
            x => 56,
            y => 510,
            xs => 200,
            ys => 300,
            pattern => "(?si:Pers.nal.*Help.*Terminal)",
            result => "OK"
        },    # kde 1280x960

        # {screenshot=>1, x=>20, y=>500, xs=>200, ys=>250, pattern=>"(?si:Accessories.*System.*Logout)", result=>"OK"} # lxde - already matched with img
    ];
}

1;
