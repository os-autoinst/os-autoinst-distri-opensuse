# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

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
