# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the advanced features of krunner, e.g. autocompletion
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use x11utils 'desktop_runner_hotkey';

sub run {
    wait_screen_change { send_key desktop_runner_hotkey };
    type_string 'echo "Hello World"';
    assert_screen 'krunner-hello_world';
    send_key 'ret';
}

1;
