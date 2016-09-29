# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: add gnome_music test; move rhythmbox test to obsoleted
# G-Maintainer: Max Lin <mlin@suse.com>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("gnome-music");
    assert_screen 'test-gnome-music-1', 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
