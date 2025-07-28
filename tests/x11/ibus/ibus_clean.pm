# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: other ibus tests
# Maintainer: Grace Wang <grace.wang@suse.com>

use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);

sub remove_input_source {
    # Since GNOME 40 or later, the 'Input Sources' is no longer in the 'Region & Language' panel
    # The 'Input Sources' is in the gnome-control-center 'Keyboard' panel now
    if (is_sle('<=15-sp3') || is_leap('<=15.3')) {
        x11_start_program "gnome-control-center region", target_match => "g-c-c-keyboard-before-clean";
    } else {
        x11_start_program "gnome-control-center keyboard", target_match => "g-c-c-keyboard-before-clean";
    }

    for my $tag (qw(chinese japanese korean)) {
        assert_and_click "ibus-input-added-$tag";
        if (is_sle('>15-sp3') || is_leap('>15.3') || is_tumbleweed) {
            assert_and_click "ibus-remove-input-source";
        }
    }
}

sub run {
    my ($self) = @_;

    assert_screen 'generic-desktop';

    remove_input_source;

    assert_screen([qw(g-c-c-region-language g-c-c-keyboard)]);
    send_key 'alt-f4';
}

1;
