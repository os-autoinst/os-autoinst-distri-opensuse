# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: tigervnc
# Summary: Remote Login: One-time VNC Session failed due to a previous graphical session
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1586208

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use x11utils 'handle_login';

sub start_vncviewer {
    x11_start_program('vncviewer 10.0.2.1:1 -Fullscreen -SecurityTypes None', target_match => [qw(displaymanager vnc_certificate_warning)]);
    if (match_has_tag 'vnc_certificate_warning') {
        send_key 'ret';
        assert_screen [qw(displaymanager vnc_certificate_warning-2)];
        if (match_has_tag 'vnc_certificate_warning-2') {
            send_key 'ret';
        }
    }
}

sub run {
    my $self = shift;

    #wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xvnc';

    # Setup the first remote connection and minimize the vncviewer
    $self->start_vncviewer;
    handle_login;
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    send_key 'z';

    # Login to the non-shared session by using another vncviewer
    $self->start_vncviewer;
    handle_login;
    assert_screen 'xvnc-multilogin-refused';
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    assert_and_click 'vncviewer-menu-exit';

    # Exit the minimized session
    hold_key 'alt';
    send_key_until_needlematch('vncviewer-minimize', 'tab');
    release_key 'alt';
    assert_screen 'generic-desktop';
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    assert_and_click 'vncviewer-menu-exit';

    mutex_unlock 'xvnc';
}

1;
