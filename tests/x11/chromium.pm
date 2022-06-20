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

sub type_address ($string) {
    send_key 'ctrl-l';    # select text in address bar
                          # wait for the urlbar to be in a consistent state
    assert_screen 'chromium-highlighted-urlbar';
    enter_cmd($string);
}

sub run {
    select_console 'x11';
    mouse_hide;
    ensure_installed 'chromium';

    # avoid async keyring popups
    # allow key input before rendering is done, see poo#109737 for details
    x11_start_program('chromium --password-store=basic --allow-pre-commit-input', target_match => 'chromium-main-window', match_timeout => 50);
    wait_screen_change { send_key 'esc' };    # get rid of popup (or abort loading)

    type_address('chrome://version');
    assert_screen 'chromium-about';

    type_address('https://html5test.opensuse.org');
    assert_screen 'chromium-html-test', 90;

    # check a site with different ssl configuration (boo#1144625)
    type_address('https://upload.wikimedia.org/wikipedia/commons/d/d0/OpenSUSE_Logo.svg');
    assert_screen 'chromium-opensuse-logo', 90;
    send_key 'alt-f4';
}

1;
