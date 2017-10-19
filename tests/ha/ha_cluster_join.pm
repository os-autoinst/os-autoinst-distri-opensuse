# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Join cluster node to existing cluster
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    # Wait until cluster is initialized
    diag 'Wait until cluster is initialized...';
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Try to join the HA cluster through node HA_CLUSTER_JOIN
    assert_script_run 'ping -c1 ' . get_var('HA_CLUSTER_JOIN');
    type_string "ha-cluster-join -yc " . get_var('HA_CLUSTER_JOIN') . "\n";
    assert_screen 'ha-cluster-join-password';
    type_password;
    send_key 'ret';
    wait_still_screen;

    # Indicate that the other nodes have joined the cluster
    barrier_wait("NODE_JOINED_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
# vim: set sw=4 et:
