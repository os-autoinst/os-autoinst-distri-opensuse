# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Remove a node both by its hostname and ip address
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;

sub remove_state_join {
    my ($method, $cluster_name, $node_01, $node_02) = @_;
    my $remove_cmd = 'crm cluster remove -y -c';
    my $join_cmd   = 'crm cluster join -y -w /dev/watchdog -i ' . get_var('SUT_NETDEVICE', 'eth0') . ' -c';
    my $timer      = 5 * get_var('TIMEOUT_SCALE', 1);

    # Waiting for the other nodes to be ready
    barrier_wait("REMOVE_NODE_BY_" . "$method" . "_INIT_" . "$cluster_name");

    # Remove the second node
    assert_script_run("$remove_cmd $node_02") if is_node(1);
    # Need to wait a bit for cluster configuration refresh
    sleep $timer;

    # Synchronize all the nodes after the remove
    barrier_wait("REMOVE_NODE_BY_" . "$method" . "_DONE_" . "$cluster_name");

    # Show cluster status
    is_node(2) ? script_run "$crm_mon_cmd" : save_state;

    # Second node needs to be reintegrated
    assert_script_run("$join_cmd $node_01") if is_node(2);

    # Synchronize all the nodes after the join
    barrier_wait("JOIN_NODE_BY_" . "$method" . "_DONE_" . "$cluster_name");

    # Need to wait a bit for cluster configuration refresh
    sleep $timer;

    # Show cluster status
    save_state;
}

sub run {
    my $cluster_name = get_cluster_name;
    my $node_01_host = choose_node(1);
    my $node_02_host = choose_node(2);
    my $node_01_ip   = get_ip($node_01_host);
    my $node_02_ip   = get_ip($node_02_host);

    # Both remove and join the second node  by its hostname
    remove_state_join('HOST', $cluster_name, $node_01_host, $node_02_host);

    # Both remove and join the second node by its IP address
    remove_state_join('IP', $cluster_name, $node_01_ip, $node_02_ip);

    # Synchronize all the nodes and save cluster status
    barrier_wait("REMOVE_NODE_FINAL_JOIN_$cluster_name");
    save_state;
}

1;
