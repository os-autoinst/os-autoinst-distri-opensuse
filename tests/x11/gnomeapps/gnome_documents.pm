# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-documents
# Summary: GNOME Documents - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    assert_gui_app('gnome-documents', install => is_sle('>=15-SP4'));
}

1;
