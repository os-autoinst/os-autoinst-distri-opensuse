# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functionality of xfce4 terminal
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('xfce4-terminal');
    wait_still_screen 1;
    send_key "ctrl-shift-t";
    $self->enter_test_text('xfce4-terminal', cmd => 1);
    assert_screen 'test-xfce4_terminal-1';
    wait_screen_change { send_key 'alt-f4' };
    # confirm close of multi-tab window
    send_key 'alt-w';
}

1;
