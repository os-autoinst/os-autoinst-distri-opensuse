## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First boot agama encryption after installation.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;

sub run {
    assert_screen("enter-passphrase-cr-swap", 200);
    save_screenshot;
    type_password();
    save_screenshot;
    send_key "ret";
    save_screenshot;
    assert_screen("text-login", 200);
    enter_cmd("root");
    # assert_screen "password-prompt";
    type_password();
    send_key('ret');
    assert_screen "text-logged-in-root";
}

1;
