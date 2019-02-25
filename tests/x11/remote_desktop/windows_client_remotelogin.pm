# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Remote Login: Windows access openSUSE/SLE over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610388

use strict;
use base 'x11test';
use testapi;
use lockapi;
use version_utils 'is_sles4sap';

sub run {
    my $self = shift;

    mutex_lock 'xrdp_server_ready';

    send_key "super-r";
    assert_screen "windows-run";
    type_string "mstsc\n";
    assert_screen "remote-desktop-connection";
    type_string '10.0.2.17';
    assert_screen "remote-ip-filled";
    send_key 'ret';
    assert_screen "verify-identity", 90;
    send_key 'y';

    assert_screen "xrdp-login-screen";
    type_string $username;    # input account name
    send_key "tab";
    type_password;
    wait_still_screen 3;
    send_key "ret";

    assert_screen "xrdp-sharing-activate", 120;
    if (is_sles4sap) {
        x11_start_program('gnome-session-quit --logout --force', valid => 0);
    }
    else {
        assert_and_click "close-xrdp-sharing-window";
        assert_and_click "confirm-close-remote-session";
    }
    assert_and_click "close-remote-desktop-connection";

    send_key "c";
}

1;
