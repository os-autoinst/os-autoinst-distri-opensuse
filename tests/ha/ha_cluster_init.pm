# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create HA cluster using ha-cluster-init
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    # Validate cluster creation with ha-cluster-init tool
    my $self          = shift;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $sbd_device    = block_device_real_path '/dev/disk/by-path/ip-*-lun-0';
    my $quorum_policy = 'stop';

    # If we failed to initialize the cluster, trying again but in debug mode
    if (script_run "ha-cluster-init -y -s $sbd_device") {
        assert_script_run "crm -dR cluster init -y -s $sbd_device";
    }

    # Signal that the cluster stack is initialized
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Waiting for the other nodes to join
    diag 'Waiting for other nodes to join...';
    barrier_wait("NODE_JOINED_$cluster_name");

    # We need to configure the quorum policy according to the number of nodes
    if (get_node_number == 2) {
        $quorum_policy = 'ignore';
    }
    assert_script_run "crm configure property no-quorum-policy=$quorum_policy";

    # Execute csync2 to synchronise the configuration files
    assert_script_run 'csync2 -v -x -F';

    # State of SBD
    assert_script_run "sbd -d $sbd_device list";

    # Check if the multicast port is correct (should be 5405 or 5407 by default)
    if (script_run "grep -Eq '^[[:blank:]]*mcastport:[[:blank:]]*(5405|5407)[[:blank:]]*' $corosync_conf") {
        record_soft_failure 'bsc#1066196';
    }

    # Do a check of the cluster with a screenshot
    save_state;

    # Status of cluster resources after initial configuration
    show_rsc;
}

1;
# vim: set sw=4 et:
