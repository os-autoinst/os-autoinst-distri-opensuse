# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: enter username and password when grub is protected
#
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    wait_still_screen;
    assert_screen 'console_grub_auth_enter_username';
    enter_cmd 'root';
    enter_cmd $testapi::password;
}

1;
