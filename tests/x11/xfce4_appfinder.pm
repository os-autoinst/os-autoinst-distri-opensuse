# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "x11test";
use strict;
use testapi;

# test xfce4-appfinder, auto-completion and starting xfce4-about

# this part contains the steps to run this test
sub run() {
    send_key "alt-f2";
    sleep 2;
    send_key "down";
    type_string "about\n";
    assert_screen 'test-xfce4_appfinder-1';
    send_key "ret";
    assert_screen 'test-xfce4_appfinder-2';
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
