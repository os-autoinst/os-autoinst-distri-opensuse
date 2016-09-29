# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add new SP2 feature (System role)
# G-Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen 'system-role-default-system';

    if (get_var("SYSTEM_ROLE")) {
        send_key 'alt-k';
        assert_screen 'system-role-kvm-virthost';
    }

    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
