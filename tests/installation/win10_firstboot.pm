# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;

use testapi;

sub run() {
    assert_screen 'windows-first-boot', 1000;
    send_key 'alt-e';                                                              # use express settings button
    assert_screen 'windows-owner', 200;
    assert_and_click 'windows-next';                                               # no alt-n shortcut
    assert_and_click 'windows-local-active-directory';
    assert_and_click 'windows-next';                                               # no alt-n shortcut
    assert_screen 'windows-user', 60;
    send_key 'tab';                                                                # select user name
    type_string $realname;
    send_key 'tab';                                                                # go to password
    type_password;
    send_key 'tab';                                                                # go to password
    type_password;
    send_key 'tab';                                                                # go to hint (hint is important for windows)
    type_string 'security';
    wait_still_screen;
    send_key 'alt-n';                                                              # next
    assert_screen 'desktop-at-first-boot', 600;
}

1;
# vim: set sw=4 et:
