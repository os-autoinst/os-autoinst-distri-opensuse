# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: ibus installation
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;

sub install_ibus {
    x11_start_program("xterm");
    become_root;
    pkcon_quit;
    wait_still_screen 1;
    zypper_call('in ibus ibus-pinyin ibus-kkc ibus-hangul');
    assert_screen 'ibus_installed';
    send_key 'ctrl-d';
    send_key 'ctrl-d';
}

sub override_i18n {
    x11_start_program('gnome-terminal');
    type_string "echo 'export INPUT_METHOD=ibus' > .i18n \n";
    type_string "cat .i18n \n";
    assert_screen 'ibus_i18n_overrided';
    send_key 'ctrl-d';
}

sub logout_and_login {
    handle_logout;
    handle_login;
}

sub ibus_daemon_started {
    x11_start_program('gnome-terminal');
    wait_still_screen;

    type_string_slow "env | grep ibus \n";
    assert_screen 'ibus-daemon-started';

    type_string_slow "ps aux | grep [i]bus \n";
    assert_screen 'ibus-process-started';

    send_key 'ctrl-d';
    assert_screen 'generic-desktop';
}

sub run {
    my ($self) = @_;

    assert_screen "generic-desktop";
    # Install ibus ibus-pinyin ibus-kkc ibus-hangul
    install_ibus;
    override_i18n;
    # Re-login to start ibus demon
    logout_and_login;

    # check if ibus has successfully started
    ibus_daemon_started;
}

1;
