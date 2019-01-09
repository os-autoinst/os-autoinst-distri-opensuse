# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: ibus enable and test korean language
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;

sub ibus_enable_source_kr {
    send_key 'super';
    type_string_slow ' region & language';
    wait_still_screen(3);
    send_key 'ret';


    assert_screen 'ibus-region-language';
    assert_and_click 'ibus-input-source-options';
    assert_and_click 'ibus-input-language-list';
    type_string 'korean';

    assert_and_click 'ibus-input-korean';
    assert_and_dclick 'ibus-input-korean-hangul';
    assert_screen 'ibus-input-added-kr';
    send_key 'alt-f4';
    assert_screen 'generic-desktop';
}

sub test_kr {
    x11_start_program('gedit');
    hold_key 'super';
    send_key_until_needlematch 'ibus_switch_kr', 'spc', 6;
    release_key 'super';

    # turn on the hangul mode
    assert_and_click 'ibus-indicator';
    assert_and_click 'ibus-korean-switch-hangul';
    type_string_slow 'dkssudgktpdy';
    send_key 'ret';
    assert_screen 'ibus_kr_hi';

    hold_key('super');
    send_key_until_needlematch 'ibus_switch_en', 'spc', 6;
    release_key('super');

    send_key 'alt-f4';
    assert_and_click 'ibus-gedit-close';

    assert_screen 'generic-desktop';
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";
    # enable Korean input sources
    ibus_enable_source_kr;

    # open gedit and test korean
    test_kr;
}

1;
