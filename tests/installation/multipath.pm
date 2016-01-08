# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    assert_screen "enable-multipath", 15;
    send_key "alt-y";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
