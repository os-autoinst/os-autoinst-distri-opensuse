# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;
use utils;

# test for bug https://bugs.freedesktop.org/show_bug.cgi?id=42301

sub run() {
    my $self = shift;
    x11_start_program("oomath");
    type_string "E %PHI = H %PHI\nnewline\n1 = 1";
    sleep 3;

    # test broken undo
    send_key "shift-left";
    send_key "2";
    send_key "ctrl-z";    # undo produces "12" instead of "1"
    sleep 3;
    assert_screen_with_soft_timeout('test-oomath-1', soft_timeout => 3);
    send_key "alt-f4";
    assert_screen_with_soft_timeout('oomath-prompt', soft_timeout => 5);
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

1;
# vim: set sw=4 et:
