# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("terminology");
    assert_screen "terminology";
    for (1 .. 13) { send_key "ret" }
    type_string "echo If you can see this text terminology is working.\n";
    assert_screen 'test-terminology-1';
    send_key "ctrl-alt-x";    # This will need to be fixed - even Enlightenment should use alt-f4, boo#983953
}

1;
# vim: set sw=4 et:
