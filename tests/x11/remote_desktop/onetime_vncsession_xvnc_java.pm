# Copyright (C) 2017 SUSE LLC
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
#
# Summary: Remote Login: One-time VNC Session with Jave applet and xvnc
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1586207

use strict;
use warnings;
use base 'basetest';
use base 'x11test';
use testapi;
use lockapi;

sub run {
    my $self = shift;

    # Wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xvnc';

    # Make sure the client gets the IP address
    x11_start_program('xterm');
    become_root;
    assert_script_run 'dhclient';
    type_string "exit\n";
    send_key 'alt-f4';

    # Start firefox
    $self->start_firefox;
    send_key 'esc';
    send_key 'alt-d';
    type_string "10.0.2.1:5801\n";
    assert_screen 'firefox-ssl-untrusted';
    assert_and_click 'firefox-ssl-untrusted-advanced';
    assert_and_click 'firefox-ssl-addexception-button';
    assert_screen 'firefox-ssl-addexception', 60;
    send_key 'alt-c';
    assert_and_click 'xvnc-firefox-activate-IcedTea';
    assert_and_click 'xvnc-firefox-IcedTea-allow';
    assert_screen 'xvnc-firefox-certification-warning';
    assert_and_click 'xvnc-firefox-trust-ca';
    assert_screen 'firefox-java-security';
    assert_and_click 'firefox-java-securityrun';
    assert_screen 'xvnc-firefox-verification-warning';
    send_key 'ret';
    assert_and_click [qw(xvnc-firefox-certification-warning2 xvnc-firefox-dm)];
    if (match_has_tag 'xvnc-firefox-certification-warning2') {
        send_key 'ret';
        assert_and_click 'xvnc-firefox-dm';
    }
    send_key 'ret';
    assert_screen 'xvnc-firefox-login-dm';
    type_password;
    send_key 'ret';
    assert_screen 'xvnc-firefox-generic-desktop';

    # Exit firefox
    $self->exit_firefox;

    mutex_unlock 'xvnc';
}

1;
