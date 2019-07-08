# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the ability to boot installed linux from cd with linuxrc.
# Maintainer: Jonathan Rivrain <jrivrain@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup "select_bootmenu_more";

sub run {
    select_bootmenu_more('inst-boot_linuxrc', 1);
    for (1 .. 3) {
        assert_screen("OK_button_linuxrc", 120);
        send_key "ret";
    }
    assert_screen "edit_kernel_options";
    send_key "ret";
    assert_screen([qw(linux-login displaymanager generic-desktop)], 180);
}


1;
