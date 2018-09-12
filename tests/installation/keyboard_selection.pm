# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Switch keyboard layout to a different language and switch back to default
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use version_utils 'is_sle';

sub switch_keyboard_layout {
    return unless get_var('INSTALL_KEYBOARD_LAYOUT');
    my $keyboard_layout = get_var('INSTALL_KEYBOARD_LAYOUT');
    # for instance, select france and test "querty"
    send_key 'alt-k';    # Keyboard Layout
    send_key_until_needlematch("keyboard-layout-$keyboard_layout", 'down', 60);
    if (check_var('DESKTOP', 'textmode')) {
        send_key 'ret';
        assert_screen "keyboard-layout-$keyboard_layout-selected";
        send_key 'alt-e';    # Keyboard Test in text mode
    }
    else {
        send_key 'alt-y';    # Keyboard Test in graphic mode
    }
    type_string "azerty";
    assert_screen "keyboard-test-$keyboard_layout";
    # Select back default keyboard layout
    send_key 'alt-k';
    send_key_until_needlematch("keyboard-layout", 'up', 60);
    wait_screen_change { send_key 'ret' } if (check_var('DESKTOP', 'textmode'));
}

sub run {
    switch_keyboard_layout;

    send_key $cmd{next} unless (is_sle('15+') && get_var('UPGRADE'));
    if (!check_var('INSTLANG', 'en_US') && check_screen 'langincomplete', 1) {
        send_key 'alt-f';
    }
}

1;
