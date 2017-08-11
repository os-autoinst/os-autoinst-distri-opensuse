# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize barriers used in HA cluster tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use lockapi;
use mmapi;

sub run {
    # Number of node is a mandatory variable!
    my $num_nodes = get_required_var('HA_NUM_NODES');

    # Initialize all barrier locks for each cluster
    for my $clustername (split(/,/, get_var('CLUSTER_NAME'))) {
        # BARRIER_HA_ needs to also wait the support-server
        barrier_create('BARRIER_HA_' . $clustername,                 $num_nodes + 1);
        barrier_create('CLUSTER_INITIALIZED_' . $clustername,        $num_nodes);
        barrier_create('NODE_JOINED_' . $clustername,                $num_nodes);
        barrier_create('DLM_INIT_' . $clustername,                   $num_nodes);
        barrier_create('DLM_GROUPS_CREATED_' . $clustername,         $num_nodes);
        barrier_create('DLM_CHECKED_' . $clustername,                $num_nodes);
        barrier_create('DRBD_INIT_' . $clustername,                  $num_nodes);
        barrier_create('DRBD_CHECK_DEVICE_NODE_02_' . $clustername,  $num_nodes);
        barrier_create('DRBD_CREATE_DEVICE_NODE_01_' . $clustername, $num_nodes);
        barrier_create('DRBD_DOWN_DONE_' . $clustername,             $num_nodes);
        barrier_create('DRBD_MIGRATION_DONE_' . $clustername,        $num_nodes);
        barrier_create('DRBD_RES_CREATED_' . $clustername,           $num_nodes);
        barrier_create('DRBD_SETUP_DONE_' . $clustername,            $num_nodes);
        barrier_create('OCFS2_INIT_' . $clustername,                 $num_nodes);
        barrier_create('OCFS2_MKFS_DONE_' . $clustername,            $num_nodes);
        barrier_create('OCFS2_GROUP_ADDED_' . $clustername,          $num_nodes);
        barrier_create('OCFS2_DATA_COPIED_' . $clustername,          $num_nodes);
        barrier_create('OCFS2_MD5_CHECKED_' . $clustername,          $num_nodes);
        barrier_create('BEFORE_FENCING_' . $clustername,             $num_nodes);
        barrier_create('FENCING_DONE_' . $clustername,               $num_nodes);
        barrier_create('LOGS_CHECKED_' . $clustername,               $num_nodes);
        barrier_create('CLVM_INIT_' . $clustername,                  $num_nodes);
        barrier_create('CLVM_RESOURCE_CREATED_' . $clustername,      $num_nodes);
        barrier_create('CLVM_PV_VG_LV_CREATED_' . $clustername,      $num_nodes);
        barrier_create('CLVM_VG_RESOURCE_CREATED_' . $clustername,   $num_nodes);
        barrier_create('CLVM_RW_CHECKED_' . $clustername,            $num_nodes);
        barrier_create('CLVM_MD5SUM_' . $clustername,                $num_nodes);
        barrier_create('MON_INIT_' . $clustername,                   $num_nodes);
        barrier_create('MON_CHECKED_' . $clustername,                $num_nodes);
    }

    # Wait for all children to start
    # Children are server/test suites that use the PARALLEL_WITH variable
    wait_for_children_to_start;

    # To synchronize all nodes (including  the support server)
    for my $clustername (split(/,/, get_var('CLUSTER_NAME'))) {
        barrier_wait('BARRIER_HA_' . $clustername);
    }
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
