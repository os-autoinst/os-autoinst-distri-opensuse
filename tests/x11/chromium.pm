# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: chromium
# Summary: Basic test of chromium visiting an html-test
# Maintainer: Stephan Kulow <coolo@suse.de>

use Mojo::Base 'x11test', -signatures;
use testapi;
use utils;

# Prevent lost characters due to temporary unresponsiveness of chromium address bar.
# It looks like chromium becomes unresponsive after typing about 3
# characters, likely due to some auto-completion feature.
# See https://progress.opensuse.org/issues/109737 for details
sub type_address ($string) {
    type_string substr($string, 0, 10), @_, max_interval => utils::SLOW_TYPING_SPEED;
    enter_cmd substr($string, 10), @_;
}

sub run {
    select_console 'x11';
    mouse_hide;
    ensure_installed 'chromium';

    # avoid async keyring popups
    x11_start_program('chromium --password-store=basic', target_match => 'chromium-main-window', match_timeout => 50);

    wait_screen_change { send_key 'esc' };    # get rid of popup (or abort loading)
    send_key 'ctrl-l';    # select text in address bar

    # Additional waiting to prevent unready address bar
    # https://progress.opensuse.org/issues/36304
    assert_screen 'chromium-highlighted-urlbar';
    type_address('chrome://version ');
    assert_screen 'chromium-about';

    send_key 'ctrl-l';
    assert_screen 'chromium-highlighted-urlbar';
    type_address('https://html5test.opensuse.org');
    assert_screen 'chromium-html-test', 90;

    # check a site with different ssl configuration (boo#1144625)
    send_key 'ctrl-l';
    assert_screen 'chromium-highlighted-urlbar';
    type_address('https://upload.wikimedia.org/wikipedia/commons/d/d0/OpenSUSE_Logo.svg');
    assert_screen 'chromium-opensuse-logo', 90;
    send_key 'alt-f4';
}

1;
