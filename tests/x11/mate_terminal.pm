# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check basic functionality of mate terminal
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('mate-terminal');
    send_key "ctrl-shift-t";
    assert_screen "mate-terminal-second-tab";
    $self->enter_test_text('mate-terminal', cmd => 1);
    assert_screen 'test-mate_terminal-1';
    send_key "alt-f4";
}

1;
