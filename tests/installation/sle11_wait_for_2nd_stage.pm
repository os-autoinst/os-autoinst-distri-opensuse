# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;
use utils;

sub run() {
    unlock_if_encrypted;
    assert_screen "second-stage", 250;
    mouse_hide;
    sleep 1;
    mouse_hide;
}

1;

# vim: sw=4 et
