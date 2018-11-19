# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test UI toolkit: Qt5
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run {
    select_console 'x11';

    x11_start_program('xterm');
    assert_script_run 'cd data/toolkits';

    assert_script_run 'make qt5';
    script_run './qt5', 0;
    assert_screen 'ui-toolkit-qt5';
    wait_screen_change { send_key 'alt-f4' };
    assert_script_run '$(exit $?)';

    type_string "exit\n";
}

1;
