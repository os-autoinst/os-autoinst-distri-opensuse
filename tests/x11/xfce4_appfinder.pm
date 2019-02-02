# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test xfce4-appfinder, auto-completion and starting xfce4-about
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;
use utils 'desktop_runner_hotkey';


sub run {
    wait_screen_change { send_key desktop_runner_hotkey };
    send_key "down";
    type_string "about\n";
    assert_screen 'test-xfce4_appfinder-1';
    send_key "ret";
    assert_screen 'test-xfce4_appfinder-2';
    send_key "alt-f4";
}

1;
