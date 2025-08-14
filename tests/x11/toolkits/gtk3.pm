# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test UI toolkit: GTK3
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use testapi;

sub run {
    select_console 'x11';

    x11_start_program('xterm');
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make gtk3';
    script_run './gtk3', 0;
    assert_screen 'ui-toolkit-gtk3';
    wait_screen_change { send_key 'alt-f4' };

    assert_script_run '$(exit $?)';
    enter_cmd 'exit';
}

1;
