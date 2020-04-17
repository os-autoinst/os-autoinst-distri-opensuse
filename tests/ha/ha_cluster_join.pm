# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add node to existing cluster
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use utils 'zypper_call';

sub run {
    my $cluster_name = get_cluster_name;
    my $node_to_join = get_node_to_join;

    # Qdevice configuration
    if (get_var('QDEVICE')) {
        zypper_call 'in corosync-qdevice';
        barrier_wait("QNETD_SERVER_READY_$cluster_name");
    }

    # Ensure that ntp service is activated/started
    activate_ntp;

    # Wait until cluster is initialized
    diag 'Wait until cluster is initialized...';
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Try to join the HA cluster through first node
    assert_script_run "ping -c1 $node_to_join";
    type_string "ha-cluster-join -yc $node_to_join ; echo ha-cluster-join-finished-\$? > /dev/$serialdev\n";
    assert_screen 'ha-cluster-join-password', $join_timeout;
    type_password;
    send_key 'ret';
    wait_serial("ha-cluster-join-finished-0", $join_timeout);

    # Indicate that the other nodes have joined the cluster
    barrier_wait("NODE_JOINED_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
