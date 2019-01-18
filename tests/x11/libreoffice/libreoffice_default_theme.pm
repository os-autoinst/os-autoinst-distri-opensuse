# LibreOffice tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LibreOffice: Default icon theme verification
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1503789

use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);
use strict;
use warnings;

sub check_lo_theme {
    x11_start_program('ooffice');
    if (is_tumbleweed || is_sle('15+')) {
        send_key 'alt-f12';
    }
    else {
        send_key "alt-t";
        assert_screen 'ooffice-menus-tools';
        send_key "o";
    }
    assert_screen 'ooffice-tools-options';
    send_key_until_needlematch 'ooffice-tools-options-view', 'down';
    send_key "esc";
    wait_still_screen 3;
    send_key "ctrl-q";    # Quit LO
}

sub run {
    my $self = shift;

    # Check LO default theme on standard GUI toolkit var
    $self->check_lo_theme;

    # Set LO GUI toolkit var to none
    x11_start_program('xterm');
    assert_script_run 'export OOO_FORCE_DESKTOP="none"';
    type_string "cd\n";
    clear_console;
    type_string "echo \$OOO_FORCE_DESKTOP\n";
    assert_screen 'ooffice-change-guitoolkit';
    send_key 'alt-f4';    # Quit xterm

    # Check LO default theme on none standard GUI toolkit var
    $self->check_lo_theme;

    # Unset LO GUI toolkit var
    x11_start_program('xterm');
    assert_script_run 'unset OOO_FORCE_DESKTOP';
    send_key 'alt-f4';    # Quit xterm
}

1;
