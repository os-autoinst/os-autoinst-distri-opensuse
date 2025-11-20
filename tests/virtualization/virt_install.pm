# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: virt-install tigervnc
# Summary: 'virt-install' test
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use testapi;
use x11utils qw(default_gui_terminal close_gui_terminal);

sub run {
    ensure_installed('virt-install');
    x11_start_program(default_gui_terminal);
    become_root;
    script_run('virt-install --name TESTING --osinfo detect=on,require=off --memory 512 --disk none --boot cdrom --graphics vnc &', 0);
    save_screenshot;
    # Choose either of the two options to turn off the pop up
    if (check_screen('allow-inhibiting-shortcuts', 10)) {
        send_key('left');
        send_key('ret');
    }
    wait_still_screen;
    # Close or at least deactivate the current window in case it would cover vncviewer later
    close_gui_terminal;
    wait_still_screen;
    x11_start_program('vncviewer :0', target_match => 'virtman-gnome_virt-install', match_timeout => 100);
    # closing all windows
    send_key 'alt-f4' for (0 .. 2);
}

1;
