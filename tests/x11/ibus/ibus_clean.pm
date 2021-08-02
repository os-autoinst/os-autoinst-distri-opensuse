# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: other ibus tests
# Maintainer: Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub remove_input_source {
    for my $tag (qw(chinese japanese korean)) {
        assert_and_click "ibus-input-added-$tag";
        assert_and_click "ibus-remove-input-source";
    }
}

sub run {
    my ($self) = @_;

    assert_screen 'generic-desktop';
    assert_and_click 'ibus-indicator';
    send_key 'esc';

    x11_start_program "gnome-control-center keyboard", target_match => "g-c-c-keyboard-before-clean";

    remove_input_source;

    assert_screen 'ibus-input-source-default';
    send_key 'alt-f4';
}

1;
