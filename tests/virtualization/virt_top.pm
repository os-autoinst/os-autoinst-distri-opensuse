# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: virt-top
# Summary: Test 'virt-top'
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use testapi;
use x11utils qw(default_gui_terminal close_gui_terminal);


sub run {
    ensure_installed('virt-top');
    x11_start_program(default_gui_terminal);
    become_root;
    script_run('virt-top', 0);
    assert_screen 'virt-top';
    close_gui_terminal;
}

1;

