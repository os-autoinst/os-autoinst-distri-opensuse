# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic test of chromium visiting an html-test
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;

sub run {
    mouse_hide;
    ensure_installed 'chromium';

    # avoid async keyring popups
    x11_start_program('chromium --password-store=basic', target_match => 'chromium-main-window', match_timeout => 50);

    wait_screen_change { send_key 'esc' };       # get rid of popup
    wait_screen_change { send_key 'ctrl-l' };    # select text in address bar
    type_string "about:\n";
    assert_screen 'chromium-about';

    wait_screen_change { send_key 'ctrl-l' };
    type_string "https://html5test.opensuse.org\n";
    assert_screen 'chromium-html-test';
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
