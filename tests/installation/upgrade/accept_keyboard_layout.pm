# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles page for keyboard layout selection.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_language_keyboard()->get_keyboard_test();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
