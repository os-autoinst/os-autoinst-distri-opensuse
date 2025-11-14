# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test UI toolkit: FLTK
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use testapi;
use x11utils 'default_gui_terminal';

sub run {
    select_console 'x11';

    x11_start_program(default_gui_terminal);
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make fltk';
    script_run './fltk', 0;
    assert_screen [qw(ui-toolkit-fltk ui-toolkit-fltk-nomsg-display)];
    if (match_has_tag 'ui-toolkit-fltk-nomsg-display') {
        # Use desktop runner to refresh screen
        record_info('Refresh screen', 'Use desktop runner to refresh screen');
        wait_screen_change { send_key 'alt-f2' };
        wait_screen_change { send_key 'esc' };
        assert_screen 'ui-toolkit-fltk';
    }
    wait_screen_change { send_key 'alt-f4' };
    assert_script_run '$(exit $?)';

    enter_cmd 'exit';
}

1;
