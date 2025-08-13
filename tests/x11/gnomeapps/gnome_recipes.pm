# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-recipes
# Summary: GNOME Weather - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('gnome-recipes');
    # assert_gui_app pressed alt-f4 to close the app, but that might have hit only
    # the '20th aniiversary gift' popup dialog
    # press again alt-f4, to close the application
    send_key('alt-f4');
}

1;
