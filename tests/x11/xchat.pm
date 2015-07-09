# Copyright (C) 2015 SUSE Linux GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "x11test";
use testapi;

sub run() {
    if (my $url = get_var("XCHAT_URL")) {
        x11_start_program("xchat --url=$url");
    }
    else {
        x11_start_program("xchat");
        assert_screen 'xchat-network-select';
        type_string "freenode\n";
        assert_and_click "xchat-connect-button";
        assert_screen 'xchat-connection-complete-dialog';
        assert_and_click "xchat-join-channel";
        type_string "openqa\n";
        send_key "ret";
    }
    assert_screen 'xchat-main-window';
    type_string "hello, this is openQA running xchat!\n";
    assert_screen 'xchat-message-sent-to-channel';
    type_string "/quit I'll be back\n";
    assert_screen 'xchat-quit';
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
