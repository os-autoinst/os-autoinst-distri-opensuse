# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: dhcp-client MozillaFirefox
# Summary: Remote Login: One-time VNC Session with Java applet and xvnc
# Maintainer: Grace Wang <grace.wang@suse.com>
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
    enter_cmd "exit";
    send_key 'alt-f4';

    # Start firefox
    $self->start_firefox;
    send_key 'esc';
    send_key 'alt-d';
    enter_cmd "10.0.2.1:5801";
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
