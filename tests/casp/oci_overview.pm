# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initial setup for one-click-installer
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use base "y2logsstep";
use utils;
use testapi;

sub run() {
    if (get_var('BETA')) {
        assert_screen 'oci-betawarning', 120;
        send_key 'ret';
    }
    assert_screen 'oci-overview', 120;
    mouse_hide;
}

1;
# vim: set sw=4 et:
