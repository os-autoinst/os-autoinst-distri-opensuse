# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functionality of gnome terminal
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('gnome-terminal');
    send_key "ctrl-shift-t";
    if (!check_screen "gnome-terminal-second-tab", 30) {
        record_info('workaround', 'gnome_terminal does not open second terminal when shortcut is pressed (see bsc#999243)');
    }
    $self->enter_test_text('gnome-terminal', cmd => 1);
    assert_screen 'test-gnome_terminal-1';
    send_key 'alt-f4';
}

1;
