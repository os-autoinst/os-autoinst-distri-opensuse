# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test formula rendering in oomath
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://bugs.freedesktop.org/show_bug.cgi?id=42301

use base "x11test";
use strict;
use testapi;

sub run() {
    x11_start_program("oomath");
    assert_screen 'oomath-textfield-ready';
    type_string "E %PHI = H %PHI\nnewline\n1 = 1";
    wait_still_screen(1);

    # test broken undo
    send_key "shift-left";
    send_key "2";
    # undo produces "12" instead of "1"
    assert_screen_change { send_key "ctrl-z" };
    assert_screen 'test-oomath-1', 3;
    assert_screen_change { send_key "alt-f4" };
    assert_screen 'oomath-prompt', 5;
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

1;
# vim: set sw=4 et:
