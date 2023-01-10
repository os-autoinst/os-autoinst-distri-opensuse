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

use base "opensusebasetest";
use version_utils qw(is_sle is_leap);
use strict;
use warnings;
use testapi;
use utils;

sub check_bsc1206793 {
    # Due to bsc#1206793, the test may fail with package version at '41.1-150400.3.3.1'
    if (is_sle || is_leap) {
        select_console 'root-console';
        if (script_output('rpm -q gnome-music') =~ '41.1-150400.3.3.1') {
            record_soft_failure 'bsc#1206793, Update breaks gnome-music';
            return 1;
        }
    }
    return 0;
}

sub run {
    return if check_bsc1206793;
    select_console 'x11';
    assert_gui_app('gnome-music', install => 1);
    send_key_until_needlematch("generic-desktop", 'alt-f4', 6, 5);
}

1;
