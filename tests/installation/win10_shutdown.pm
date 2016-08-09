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
    send_key 'super';                                                              # windows menu
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'spc';                                                                # press power button
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'spc';                                                                # press shutdown button
    assert_shutdown;
}

1;
# vim: set sw=4 et:
