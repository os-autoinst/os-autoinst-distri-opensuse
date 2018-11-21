# SUSE's openQA tests
#
# Author: Gao Zhiyuan <zgao@suse.com>
# Copyright © SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: setup and test ibus japanese input
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;

sub ibus_enable_source_jp {
    send_key 'super';
    wait_still_screen;
    type_string_slow ' region & language';
    wait_still_screen(3);
    send_key 'ret';

    assert_screen 'ibus-region-language';
    assert_and_click 'ibus-input-source-options';
    assert_and_click 'ibus-input-language-list';
    type_string 'japanese';

    assert_and_click 'ibus-input-japanese';
    assert_and_dclick 'ibus-input-japanese-kkc';
    assert_screen 'ibus-input-added-jp';
    send_key 'alt-f4';
    assert_screen 'generic-desktop';
}

sub test_jp {
    x11_start_program('gedit');
    hold_key('super');
    send_key_until_needlematch 'ibus_switch_jp', 'spc', 6;
    release_key('super');

    wait_still_screen(3);
    type_string_slow 'konnnichiha';
    send_key 'ret';
    assert_screen 'ibus_jp_hi';

    hold_key 'super';
    send_key_until_needlematch 'ibus_switch_en', 'spc', 6;
    release_key 'super';

    send_key 'alt-f4';
    assert_and_click 'ibus-gedit-close';
    assert_screen 'generic-desktop';
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";

    # enable Japanses input sources
    ibus_enable_source_jp;

    # open gedit and test chinese
    test_jp;
}

1;
