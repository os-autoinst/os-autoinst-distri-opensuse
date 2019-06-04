# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create HA cluster using ha-cluster-init
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;

sub run {
    # Validate cluster creation with ha-cluster-init tool
    my $cluster_name  = get_cluster_name;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $sbd_device    = get_lun;
    my $unicast_opt   = get_var("HA_UNICAST") ? '-u' : '';
    my $quorum_policy = 'stop';
    my $join_timeout  = 60;
    my $fencing_opt   = "-s $sbd_device";

    # If we failed to initialize the cluster, trying again but in debug mode
    # Note: the default timeout need to be increase because it can takes time to join the cluster
    # Initialize the cluster with diskless or shared storage SBD (default)
    $fencing_opt = '-S' if (get_var('USE_DISKLESS_SBD'));
    if (script_run "ha-cluster-init -y $fencing_opt $unicast_opt", $join_timeout) {
        assert_script_run "crm -dR cluster init -y $fencing_opt $unicast_opt", $join_timeout;
    }

    # Signal that the cluster stack is initialized
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Waiting for the other nodes to join
    diag 'Waiting for other nodes to join...';
    barrier_wait("NODE_JOINED_$cluster_name");

    # We need to configure the quorum policy according to the number of nodes
    $quorum_policy = 'ignore' if (get_node_number == 2);
    assert_script_run "crm configure property no-quorum-policy=$quorum_policy";

    # Execute csync2 to synchronise the configuration files
    exec_csync;

    # State of SBD if shared storage SBD is used
    assert_script_run "sbd -d $sbd_device list" unless (get_var('USE_DISKLESS_SBD'));

    # Check if the multicast port is correct (should be 5405 or 5407 by default)
    assert_script_run "grep -Eq '^[[:blank:]]*mcastport:[[:blank:]]*(5405|5407)[[:blank:]]*' $corosync_conf";

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
