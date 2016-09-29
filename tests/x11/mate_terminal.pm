# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Other Desktop Environments: Mate
# G-Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("mate-terminal");
    assert_screen "mate-terminal";
    send_key "ctrl-shift-t";
    assert_screen "mate-terminal-second-tab";
    for (1 .. 13) { send_key "ret" }
    type_string "echo If you can see this text mate-terminal is working.\n";
    assert_screen 'test-mate_terminal-1';
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
