# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Let real hardware boot to BIOS and PXE menu before grub_test
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "basetest";
use strict;
use testapi;

sub run {
    if (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
    }
    assert_screen 'pxe-menu-nue', 300;
    # boot to hard disk is default
    send_key 'ret';

}

sub test_flags {
    return {fatal => 1};
}


1;

