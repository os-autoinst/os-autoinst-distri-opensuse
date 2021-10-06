# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Switch keyboard layout and test it
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert ':all';

sub run {
    my $language_keyboard = $testapi::distri->get_language_keyboard();
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
