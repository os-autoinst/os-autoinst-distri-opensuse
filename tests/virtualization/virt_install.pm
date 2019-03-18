# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: 'virt-install' test
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('virt-install');
    x11_start_program('xterm');
    become_root;
    script_run('virt-install --name TESTING --memory 512 --disk none --boot cdrom --graphics vnc &', 0);
    wait_still_screen(15);
    x11_start_program('vncviewer :0', target_match => 'virtman-gnome_virt-install', match_timeout => 100);
    # closing all windows
    send_key 'alt-f4' for (0 .. 2);
}

1;
