# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test 'virt-top'
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use strict;
use warnings;
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

