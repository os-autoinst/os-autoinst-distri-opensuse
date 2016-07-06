# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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
    x11_start_program("gnome-tweak-tool");
    assert_screen "gnome-tweak-tool-started";
    assert_and_click "gnome-tweak-tool-fonts";
    assert_screen "gnome-tweak-tool-fonts-dialog";
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
