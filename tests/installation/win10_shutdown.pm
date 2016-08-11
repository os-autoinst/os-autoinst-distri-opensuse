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
    send_key 'super';             # windows menu
    assert_screen 'windows-menu';
    send_key 'up';
    send_key 'up';
    send_key 'spc';               # press power button
    send_key 'up';
    send_key 'up';
    send_key 'shift-ret';         # press shutdown button, use shift to avoid hybrid-shutdown
    assert_shutdown;
}

1;
# vim: set sw=4 et:
