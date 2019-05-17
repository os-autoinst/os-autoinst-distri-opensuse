# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Keyboard layout test in console and display manager after boot
# Maintainer: Oliver Kurz <okurz@suse.com>

use base "locale";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    # uncomment in case of different keyboard than us is used during installation ( feature not ready yet )
    # my $expected   = get_var('INSTALL_KEYBOARD_LAYOUT','us');
    my $expected   = 'us';
    my $keystrokes = $self->get_keystroke_list($expected);

    $self->verify_default_keymap_x11($keystrokes, "${expected}_keymap_logged_x11", 'xterm');

    assert_screen("generic-desktop");
}

sub test_flags {
    return {milestone => 1};
}
1;
