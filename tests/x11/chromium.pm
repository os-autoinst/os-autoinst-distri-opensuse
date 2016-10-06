# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic test of chromium visiting html5test.com
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    mouse_hide;

    ensure_installed("chromium");

    # avoid async keyring popups
    x11_start_program("chromium --password-store=basic");

    assert_screen 'chromium-main-window', 50;

    send_key "esc";       # get rid of popup
    sleep 1;
    send_key "ctrl-l";    # select text in address bar
    sleep 1;
    type_string "about:\n";
    assert_screen 'chromium-about', 15;

    send_key "ctrl-l";
    sleep 1;
    type_string "https://html5test.com/index.html\n";
    assert_screen 'chromium-html5test', 30;

    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
