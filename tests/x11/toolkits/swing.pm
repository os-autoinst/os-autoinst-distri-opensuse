# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test UI toolkit: Java Swing
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run {
    select_console 'x11';

    x11_start_program('xterm');
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make swing.class';
    script_run 'java swing', 0;
    assert_screen 'ui-toolkit-swing';
    wait_screen_change { send_key 'alt-f4' };
    assert_script_run '$(exit $?)';

    type_string "exit\n";
}

1;
