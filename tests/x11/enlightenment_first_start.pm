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
use utils;

sub run() {
    my $self = shift;
    mouse_hide();
    assert_and_click "enlightenment_profile_selection";
    assert_and_click "enlightenment_assistant_next";
    assert_and_click "enlightenment_profile_size";
    assert_and_click "enlightenment_assistant_next";
    assert_screen "enlightenment_windowfocus";
    assert_and_click "enlightenment_assistant_next";
    assert_screen "enlightenment_compositing";
    assert_and_click "enlightenment_assistant_next";
    assert_screen "enlightenment_generic_desktop";
}

sub test_flags() {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
