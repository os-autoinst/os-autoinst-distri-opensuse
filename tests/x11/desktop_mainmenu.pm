# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test desktop main menue shows up.
#   Support for different WMs/DEs
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    # some desktops need some time to accept user input
    sleep 10;
    if (check_var("DESKTOP", "lxde")) {
        # or Super_L or Windows key
        x11_start_program('lxpanelctl menu', target_match => 'test-desktop_mainmenu-1');
    }
    elsif (check_var("DESKTOP", "xfce")) {
        mouse_set(0, 0);
        sleep 1;
        send_key "ctrl-esc";    # open menu
        sleep 1;
        send_key "up";          # go into Applications submenu
        mouse_hide(1);
    }
    else {
        send_key_until_needlematch 'test-desktop_mainmenu-1', 'alt-f1', 5, 10;
    }
    assert_screen 'test-desktop_mainmenu-1', 20;

    send_key "esc";
}

sub ocr_checklist {
    [

        {
            screenshot => 1,
            x          => 30,
            y          => 30,
            xs         => 200,
            ys         => 250,
            pattern    => "(?si:ccessories.*Internet.*ffice.*Universal .ccess)",
            result     => "OK"
        },    # gnome
        {
            screenshot => 1,
            x          => 20,
            y          => 5,
            xs         => 200,
            ys         => 250,
            pattern    => "(?si:reate .auncher.*reate..?older.*pen Terminal Here.*rrange Des.top .cons)",
            result     => "OK"
        },    # xfce
        {
            screenshot => 1,
            x          => 56,
            y          => 510,
            xs         => 200,
            ys         => 300,
            pattern    => "(?si:Pers.nal.*Help.*Terminal)",
            result     => "OK"
        },    # kde 1280x960

        # {screenshot=>1, x=>20, y=>500, xs=>200, ys=>250, pattern=>"(?si:Accessories.*System.*Logout)", result=>"OK"} # lxde - already matched with img
    ];
}

1;
