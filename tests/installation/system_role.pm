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
use utils 'sle_version_at_least';

sub assert_system_role {
    # Still initializing the system at this point, can take some time
    assert_screen 'system-role-default-system', 180;

    # Pick System Role; poo#16650
    if (check_var('SYSTEM_ROLE', 'kvm')) {
        send_key 'alt-k';
        assert_screen 'system-role-kvm-virthost';
    }
    elsif (check_var('SYSTEM_ROLE', 'xen')) {
        send_key 'alt-x';
        assert_screen 'system-role-xen-virthost';
    }

    send_key $cmd{next};
}

sub assert_system_role_with_workaround_sle15_aarch64_missing_system_role {
    # Workaround for bsc#1049297
    # When the workaround is no more needed, execute on `sub run` only the function `sub assert_system_role`
    wait_still_screen;
    # SLE 15 will always show the system role
    if (sle_version_at_least('15') && check_var('ARCH', 'aarch64')) {
        assert_screen 'partitioning-edit-proposal-button';
        record_soft_failure 'bsc#1049297 - missing system role';
    }
    else {
        assert_system_role;
    }
}

sub run {
    assert_system_role_with_workaround_sle15_aarch64_missing_system_role;
}

1;
# vim: set sw=4 et:
