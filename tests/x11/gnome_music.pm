# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-music
# Summary: Gnome music startup
# - Launch gnome-music and check if it is running
# - Close gnome-music
# Maintainer: Max Lin <mlin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    assert_gui_app('gnome-music', install => 1);
    send_key_until_needlematch("generic-desktop", 'alt-f4', 6, 5);
}

1;
