# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status *after* reboot
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    # In ppc64le and aarch64, workers are slower
    set_var('TIMEOUT_SCALE', 2) unless (check_var('ARCH', 'x86_64'));

    # Check cluster state *after* reboot
    barrier_wait("CHECK_AFTER_REBOOT_BEGIN_$cluster_name");

    # We need to be sure to be root and, after fencing, the default console on node01 is not root
    # Only do this on node01, as node02 console is expected to be the root-console
    if (is_node(1) && !get_var('HDDVERSION')) {
        reset_consoles;
        select_console 'root-console';
    }
    # This code is also called after boot on update tests. We must ensure to be on the root console
    # in that case
    select_console 'root-console' if (get_var('HDDVERSION'));

    # Wait for resources to be started
    wait_until_resources_started;

    # And check for the state of the whole cluster
    check_cluster_state;

    # Synchronize all nodes
    barrier_wait("CHECK_AFTER_REBOOT_END_$cluster_name");
}

1;
