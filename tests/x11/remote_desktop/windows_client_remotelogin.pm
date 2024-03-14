# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: gnome-session-core
# Summary: Remote Login: Windows access openSUSE/SLE over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610388

use strict;
use warnings;
use base 'x11test';
use testapi;
use lockapi;
use version_utils qw(is_sles4sap is_tumbleweed);

sub run {
    my $self = shift;

    mutex_lock 'xrdp_server_ready';

    send_key "super-r";
    assert_screen "windows-run";
    enter_cmd "mstsc";
    assert_screen "remote-desktop-connection";
    type_string '10.0.2.17';
    assert_screen "remote-ip-filled";
    send_key 'ret';
    if (check_screen "accept-custom-cert", 90) {
        send_key 'y';
    } else {
        assert_screen "verify-identity", 90;
        send_key 'y';
    }
    assert_screen "xrdp-login-screen";
    type_string $username;    # input account name
    send_key "tab";
    type_password;
    wait_still_screen 3;
    send_key "ret";

    assert_screen "xrdp-sharing-activate", 120;

    if (is_sles4sap || is_tumbleweed) {
        x11_start_program('gnome-session-quit --logout --force', valid => 0);
    }
    else {
        assert_and_click "close-xrdp-sharing-window";
        assert_and_click "confirm-close-remote-session";
    }
    assert_and_click [qw(close-remote-desktop-connection remote-desktop-connection-ended)];

    send_key "c";
}

1;
