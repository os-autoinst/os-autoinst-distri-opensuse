# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test UI toolkit: FLTK
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';

    x11_start_program('xterm');
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make fltk';
    script_run './fltk', 0;
    assert_screen 'ui-toolkit-fltk';
    wait_screen_change { send_key 'alt-f4' };
    assert_script_run '$(exit $?)';

    enter_cmd 'exit';
}

1;
