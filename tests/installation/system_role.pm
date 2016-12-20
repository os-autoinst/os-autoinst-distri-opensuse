# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check system role selection screen. Added in SLE 12 SP2
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    # Still initializing the system at this point, can take some time
    assert_screen 'system-role-default-system', 180;

    if (get_var("SYSTEM_ROLE")) {
        send_key 'alt-k';
        assert_screen 'system-role-kvm-virthost';
    }

    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
