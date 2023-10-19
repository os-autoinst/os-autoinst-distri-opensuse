# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test UI toolkit: X11
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';

    x11_start_program('xterm');

    script_run 'xmessage "Hello World: X11"', 0;
    assert_screen 'ui-toolkit-x11';
    wait_screen_change { send_key 'alt-f4' };
    # xmessage returns 1 if not closed via okay button
    assert_script_run '$(test $? == 1 ; exit $?)';

    enter_cmd 'exit';
}

1;
