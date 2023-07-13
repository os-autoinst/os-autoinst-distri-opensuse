# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gedit ibus
# Summary: ibus enable and test korean language
# Maintainer: Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub test_kr {
    ensure_installed('gedit');
    x11_start_program('gedit');
    hold_key 'super';
    send_key_until_needlematch 'ibus_switch_kr', 'spc', 7;
    release_key 'super';

    # turn on the hangul mode
    assert_and_click 'ibus-indicator';
    assert_and_click 'ibus-korean-switch-hangul';
    type_string_slow 'dkssudgktpdy';
    send_key 'ret';
    assert_screen 'ibus_kr_hi';

    hold_key('super');
    send_key_until_needlematch 'ibus_switch_en', 'spc', 7;
    release_key('super');

    send_key 'alt-f4';
    assert_and_click 'ibus-gedit-close';

    assert_screen 'generic-desktop';
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";
    # add Korean input source
    $self->add_input_resource("korean");

    # open gedit and test korean
    test_kr;
}

1;
