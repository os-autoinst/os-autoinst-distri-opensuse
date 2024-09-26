## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot agama encryption.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;

sub run {
    assert_screen("encrypted-disk-password-prompt", 200);
    save_screenshot;
    type_password();
    save_screenshot;
    send_key "ret";
    save_screenshot;
    assert_screen("grub2", 200);
}

1;
