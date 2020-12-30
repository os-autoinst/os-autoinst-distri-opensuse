# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: terminology
# Summary: Test enlightenment terminal emulator 'terminology'
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    x11_start_program('teminology', target_match => [qw(terminology terminology-config-scale)]);
    # Somehow the window loses focus after click_lastmatch hides the mouse, avoid that
    mouse_set(25, 25);
    click_lastmatch if match_has_tag('terminology-config-scale');
    $self->enter_test_text('terminology', cmd => 1);
    mouse_hide(1);
    assert_screen('test-terminology-1');
    send_key('alt-f4');
}

1;
