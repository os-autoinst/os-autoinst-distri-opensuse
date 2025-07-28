# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Keyboard layout test in console and display manager after boot
# - Access console as root
#   - Type keystrokes for selected language (default = us)
# - Access console as user
#   - Type keystrokes for selected language (default = us)
# Maintainer: QE Core <qe-core@suse.de>

use base "locale";
use Utils::Backends 'has_ttys';
use testapi qw(assert_screen get_var select_console);

sub run {
    my ($self) = @_;
    select_console('user-console') unless get_var('INSTALL_KEYBOARD_LAYOUT');
    my $expected = get_var('INSTALL_KEYBOARD_LAYOUT', 'us');
    # Feature of switching keyboard during installation is not ready yet,
    # so if another language is used it needs to be verfied that the needle represents properly
    # characters on that language. Therefore we use 'us' instead of $expected
    my $keystrokes = $self->get_keystroke_list('us');

    assert_screen([qw(linux-login cleared-console)]);
    return $self->verify_default_keymap_textmode_non_us($keystrokes, "${expected}_keymap") if ($expected ne 'us');
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap");
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'root-console');
    # ensure_serialdev_permissions is not needed as it is executing by system_prepare
    $self->verify_default_keymap_textmode($keystrokes, "${expected}_keymap", console => 'user-console');
}

sub test_flags {
    return {milestone => 1};
}

1;
