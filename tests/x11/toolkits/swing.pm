# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test UI toolkit: Java Swing
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use testapi;
use x11utils 'default_gui_terminal';

sub run {
    select_console 'x11';

    x11_start_program(default_gui_terminal);
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make swing.class';
    script_run 'java swing', 0;
    assert_screen 'ui-toolkit-swing';
    wait_screen_change { send_key 'alt-f4' };
    assert_script_run '$(exit $?)';

    enter_cmd 'exit';
}

1;
