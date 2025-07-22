# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: virt-top
# Summary: Test 'virt-top'
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use testapi;


sub run {
    ensure_installed('virt-top');
    x11_start_program('xterm');
    become_root;
    script_run('virt-top', 0);
    assert_screen 'virt-top';
    send_key 'alt-f4';
}

1;

