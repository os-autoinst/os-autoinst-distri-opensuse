# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Keyboard layout test in console and display manager after boot
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "locale";
use strict;
use warnings;
use Utils::Backends 'has_ttys';
use testapi qw(assert_screen get_var);
use utils 'ensure_serialdev_permissions';

sub run {
    my ($self) = @_;
    my $expected = get_var('INSTALL_KEYBOARD_LAYOUT', 'us');
    # Feature of switching keyboard during installation is not ready yet,
    # so if another language is used it needs to be verfied that the needle represents properly
    # characters on that language.
    my $keystrokes = $self->get_keystroke_list($expected);

    assert_screen([qw(linux-login cleared-console)]);
    return $self->verify_default_keymap_textmode_non_us($keystrokes, "${expected}_keymap") if ($expected ne 'us');
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap");
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'root-console');
    ensure_serialdev_permissions;
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'user-console');
}

sub test_flags {
    return {milestone => 1};
}

1;
