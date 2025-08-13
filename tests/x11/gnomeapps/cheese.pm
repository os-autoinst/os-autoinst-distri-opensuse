# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cheese
# Summary: GNOME Cheese - WebCam Analyzer - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('cheese');
}

1;
