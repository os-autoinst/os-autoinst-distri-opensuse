# LibreOffice tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice
# Summary: LibreOffice: Default icon theme verification
# - Start ooffice
# - Open options menu and check
# - Quit ooffice
# - Launch xterm, run export OOO_FORCE_DESKTOP="none" and check
# - Close xterm
# - Start ooffice
# - Open options menu and check
# - Quit ooffice
# - Launch xterm, unset OOO_FORCE_DESKTOP and close xterm
# Maintainer: Zhaocong Jia <zcjia@suse.com>
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
    send_key_until_needlematch 'ooffice-tools-options-view', 'down', 6, 2;
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
    enter_cmd "cd";
    clear_console;
    enter_cmd "echo \$OOO_FORCE_DESKTOP";
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
