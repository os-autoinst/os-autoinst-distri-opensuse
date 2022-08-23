# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gedit ibus
# Summary: setup and test ibus japanese input
# Maintainer: Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub test_jp {
    x11_start_program('gedit');
    hold_key('super');
    send_key_until_needlematch 'ibus_switch_jp', 'spc', 7;
    release_key('super');

    wait_still_screen(3);
    type_string_slow 'konnnichiha';
    send_key 'ret';
    assert_screen 'ibus_jp_hi';

    hold_key 'super';
    send_key_until_needlematch 'ibus_switch_en', 'spc', 7;
    release_key 'super';

    send_key 'alt-f4';
    assert_and_click 'ibus-gedit-close';
    assert_screen 'generic-desktop';
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";

    # add Japanses input source
    $self->add_input_resource("japanese");

    # open gedit and test chinese
    test_jp;
}

1;
