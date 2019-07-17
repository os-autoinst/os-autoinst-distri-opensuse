# Copyright (C) 2015-2019 SUSE LLC
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

# Summary: Test both hexchat and xchat in one test
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $name = ref($_[0]);
    ensure_installed($name);
    x11_start_program($name, target_match => "$name-network-select");
    type_string "freenode\n";
    assert_and_click "hexchat-nick-$username";
    send_key 'ctrl-a';
    send_key 'delete';
    assert_screen "hexchat-nick-empty";
    type_string "openqa" . random_string(5);
    assert_and_click "$name-connect-button";
    assert_screen "$name-connection-complete-dialog";
    assert_and_click "$name-join-channel";
    type_string "openqa\n";
    send_key 'ret';
    assert_screen "$name-main-window";
    type_string "hello, this is openQA running $name!\n";
    assert_screen "$name-message-sent-to-channel";
    type_string "/quit I'll be back\n";
    assert_screen "$name-quit";
    send_key 'alt-f4';
}

1;
