# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-2048
# Summary: GNOME 2048 - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('gnome-2048');
}

1;
