# SUSE's openQA tests
#
# Copyright Â© 2009-2013 Bernhard M. Wiedemann
# Copyright Â© 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: select and boot RT in grub menu
# Maintainer: Martin Loviska <mloviska@suse.com>

use base 'opensusebasetest';
use testapi;
use bootloader_setup 'boot_grub_item';
use x11utils 'handle_login';

sub run() {
    boot_grub_item(2, 3);
    assert_screen 'displaymanager', 60;
    handle_login;
}

1;
