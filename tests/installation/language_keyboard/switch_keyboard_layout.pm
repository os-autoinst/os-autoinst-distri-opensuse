# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Switch keyboard layout and test it
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert ':all';

sub run {
    my $language_keyboard = $testapi::distri->get_language_keyboard();
    # wait for the English (US) to be pre-selected as on slow architectures it takes some time
    $language_keyboard->wait_for_keyboard_layout_to_be_selected('English (US)');
    $language_keyboard->switch_keyboard_layout('French');
    $language_keyboard->enter_keyboard_test('azerty');
    my $keyboard_test = $language_keyboard->get_keyboard_test();
    $language_keyboard->switch_keyboard_layout('English (US)');
    assert_equals('qwerty', $keyboard_test, 'Test keyboard failed');
}

sub test_flags {
    return {fatal => 0};
}

1;
