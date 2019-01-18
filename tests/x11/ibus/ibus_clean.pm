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
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub remove_ch {
    assert_and_click 'ibus-input-added-ch';
    assert_and_click 'ibus-input-remove';
}

sub remove_jp {
    assert_and_click 'ibus-input-added-jp';
    assert_and_click 'ibus-input-remove';
}

sub remove_kr {
    assert_and_click 'ibus-input-added-kr';
    assert_and_click 'ibus-input-remove';
}

sub run {
    my ($self) = @_;

    assert_screen 'generic-desktop';
    assert_and_click 'ibus-indicator';
    send_key 'esc';

    send_key 'super';
    wait_still_screen;
    type_string_slow ' region & language';
    wait_still_screen;
    send_key 'ret';

    assert_screen 'ibus-region-language';
    remove_ch;
    remove_jp;
    remove_kr;

    assert_screen 'ibus-region-language-empty';
    send_key 'alt-f4';
}

1;
