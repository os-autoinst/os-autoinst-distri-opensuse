# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Wait for guests so they finish the installation
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run 'virsh list --all';
    add_guest_to_hosts $_, $virt_autotest::common::guests{$_}->{ip} foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat /etc/hosts";

    # Check that guests are online so we can continue and setup them
    ensure_online $_, skip_ssh => 1, ping_delay => 45 foreach (keys %virt_autotest::common::guests);

    # All guests should be now installed and running
    assert_script_run 'virsh list --all';
    wait_still_screen 1;
}

1;
