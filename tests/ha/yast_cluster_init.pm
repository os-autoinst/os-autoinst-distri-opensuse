# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Deploy a cluster with YaST
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(zypper_call systemctl exec_and_insert_password);
use hacluster;

sub run {
    my $cluster_name  = get_cluster_name;
    my $hostname      = get_hostname;
    my $quorum_policy = 'stop';
    my $node_01_host  = choose_node(1);
    my $node_02_host  = choose_node(2);

    # Start yast2 cluster module
    script_run("yast2 cluster; echo yast2-cluster-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast-cluster-overview', 60;

    # Bind network address
    send_key 'alt-w';    # Bind network adress
    save_screenshot;

    # Remove preconfigured network
    for (1 .. 11) { send_key 'backspace'; }
    type_string "10.0.2.0";

    # Configure expected votes
    send_key 'alt-x';
    type_string "1";
    wait_screen_change { send_key 'alt-n' };

    # Corosync settings screen
    assert_screen 'yast-cluster-corosync';
    wait_screen_change { send_key 'alt-n' };

    # Security settings screen
    assert_screen 'yast-cluster-security';
    wait_screen_change { send_key 'alt-n' };

    # Csync2 settings screen
    assert_screen 'yast-cluster-csync2';
    send_key 'alt-G';    # Generate Pre-Shared-Keys
    send_key 'alt-O';    # Validation
    send_key 'alt-S';    # Add suggested files
    send_key 'alt-A';    # Add Sync host
    type_string "$hostname";
    send_key 'alt-O';    # Validation
    send_key 'alt-u';    # Turn csync2 on
    wait_still_screen 5;
    save_screenshot;
    wait_screen_change { send_key 'alt-n' };

    # Conntrack settings screen
    assert_screen 'yast-cluster-conntrackd';
    wait_screen_change { send_key 'alt-n' };

    # Cluster service settings screen
    assert_screen 'yast-cluster-service';
    send_key 'alt-a';    # Start pacemaker during boot
    send_key 'alt-S';    # Start pacemaker now
    wait_still_screen 5;
    wait_screen_change { send_key "alt-n" };
    save_screenshot;
    wait_still_screen 5;
    save_screenshot;
    save_state;

    # Generate ssh key
    assert_script_run 'ssh-keygen -f /root/.ssh/id_rsa -N ""';
    assert_script_run 'cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys';

    # Signal that the cluster stack is initialized
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Wait until all the nodes have ssh key configured
    diag 'Waiting for other nodes to configure SSH...';
    barrier_wait("SSH_KEY_CONFIGURED_$cluster_name");

    # Wait until csync2 is configured in the other nodes
    diag 'Waiting for other nodes to configure csync2...';
    barrier_wait("CSYNC2_CONFIGURED_$cluster_name");

    # Synchronize files with csync2
    exec_csync;

    # Files are synchronized, pacemaker could be start in the other nodes
    diag 'Waiting for other nodes to synchronize files...';
    barrier_wait("CSYNC2_SYNC_$cluster_name");

    # Waiting for the other nodes to join
    diag 'Waiting for other nodes to join...';
    barrier_wait("NODE_JOINED_$cluster_name");

    # We need to configure the quorum policy according to the number of nodes
    $quorum_policy = 'ignore' if (get_node_number == 2);
    assert_script_run "crm configure property no-quorum-policy=$quorum_policy have-watchdog=true stonith-enabled=true";
    assert_script_run "crm configure rsc_defaults resource-stickiness=1 migration-threshold=3";
    assert_script_run "crm configure op_defaults timeout=600 record-pending=true";
    sleep 5;

    # Synchronize files with csync2
    exec_csync;
    save_state;
}

1;
