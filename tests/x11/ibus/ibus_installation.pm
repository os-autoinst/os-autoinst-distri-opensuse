# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: ibus ibus-libpinyin ibus-pinyin ibus-kkc ibus-hangul
# gnome-terminal
# Summary: ibus installation
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';
use x11utils 'handle_relogin';

sub install_ibus {
    x11_start_program("xterm");
    become_root;
    quit_packagekit;
    wait_still_screen 1;
    my $ibus_pinyin = is_tumbleweed() ? "ibus-libpinyin" : "ibus-pinyin";
    zypper_call("in ibus $ibus_pinyin ibus-kkc ibus-hangul");
    assert_screen 'ibus_installed';
    send_key 'ctrl-d';
    send_key 'ctrl-d';
}

sub override_i18n {
    x11_start_program('gnome-terminal');
    enter_cmd "echo 'export INPUT_METHOD=ibus' > .i18n ";
    enter_cmd "cat .i18n ";
    assert_screen 'ibus_i18n_overrided';
    send_key 'ctrl-d';
}

sub ibus_daemon_started {
    x11_start_program('gnome-terminal');
    wait_still_screen;

    enter_cmd_slow "env | grep ibus ";
    assert_screen 'ibus-daemon-started';

    enter_cmd_slow "ps aux | grep [i]bus ";
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
    handle_relogin;

    # check if ibus has successfully started
    ibus_daemon_started;
}

sub test_flags {
    return {milestone => 1};
}

1;
