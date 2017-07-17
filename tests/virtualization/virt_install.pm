# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: 'virt-install' test
# Maintainer: aginies <aginies@suse.com>

use base "x11test";
use strict;
use testapi;

sub run {
    ensure_installed("virt-install");
    x11_start_program("xterm");
    wait_idle;
    become_root;
    script_run("virt-install --name TESTING --memory 512 --disk none --boot cdrom --graphics vnc &");
    x11_start_program("vncviewer :0");
    wait_idle;
    assert_screen "virtman-sle12sp1-gnome_virt-install", 100;
    for (0 .. 2) {
        send_key "alt-f4";
    }    # closing all windows
}

1;
# vim: set sw=4 et:

