# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the KDE text editor can be installed, started, typing works
#   and closed
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    ensure_installed("kate");
    x11_start_program('kate');

    if (!get_var("PLASMA5")) {
        # close welcome screen
        wait_screen_change { send_key 'alt-c' };
    }
    # type slow as kate can garble up text when typing with the super natural
    # standard speed
    $self->enter_test_text('kate', slow => 1);
    assert_screen 'test-kate-2';
    send_key "ctrl-q";
    assert_screen 'test-kate-3';
    send_key "alt-d";    # discard
}

1;
