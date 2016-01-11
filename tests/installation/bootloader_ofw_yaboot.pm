# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    assert_screen "bootloader-ofw-yaboot", 15;
    if (check_var('VIDEOMODE', 'text')) {
        type_string "install textmode=1", 15;
    }
    send_key "ret";
}

1;
# vim: set sw=4 et:
