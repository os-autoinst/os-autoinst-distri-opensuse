# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize barriers used in HA cluster tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use mmapi;
use hacluster;

sub run {
    for my $cluster_infos (split(/,/, get_required_var('CLUSTER_INFOS'))) {
        # The CLUSTER_INFOS variable for support_server also contains the number of node
        my ($cluster_name, $num_nodes) = split(/:/, $cluster_infos);

        # Number of node is a mandatory variable!
        if ($num_nodes lt '2') {
            die 'A valid number of nodes is mandatory';
        }

        # BARRIER_HA_ needs to also wait the support-server
        barrier_create("BARRIER_HA_$cluster_name",                  $num_nodes + 1);
        barrier_create("CLUSTER_INITIALIZED_$cluster_name",         $num_nodes);
        barrier_create("NODE_JOINED_$cluster_name",                 $num_nodes);
        barrier_create("DLM_INIT_$cluster_name",                    $num_nodes);
        barrier_create("DLM_GROUPS_CREATED_$cluster_name",          $num_nodes);
        barrier_create("DLM_CHECKED_$cluster_name",                 $num_nodes);
        barrier_create("DRBD_INIT_$cluster_name",                   $num_nodes);
        barrier_create("DRBD_CREATE_CONF_$cluster_name",            $num_nodes);
        barrier_create("DRBD_ACTIVATE_DEVICE_$cluster_name",        $num_nodes);
        barrier_create("DRBD_CREATE_DEVICE_$cluster_name",          $num_nodes);
        barrier_create("DRBD_DOWN_DONE_$cluster_name",              $num_nodes);
        barrier_create("DRBD_MIGRATION_DONE_$cluster_name",         $num_nodes);
        barrier_create("DRBD_REVERT_DONE_$cluster_name",            $num_nodes);
        barrier_create("DRBD_RESOURCE_CREATED_$cluster_name",       $num_nodes);
        barrier_create("DRBD_RESOURCE_STOPPED_$cluster_name",       $num_nodes);
        barrier_create("DRBD_RESOURCE_STARTED_$cluster_name",       $num_nodes);
        barrier_create("DRBD_SETUP_DONE_$cluster_name",             $num_nodes);
        barrier_create("LOCK_INIT_$cluster_name",                   $num_nodes);
        barrier_create("LOCK_RESOURCE_CREATED_$cluster_name",       $num_nodes);
        barrier_create("BEFORE_FENCING_$cluster_name",              $num_nodes);
        barrier_create("FENCING_DONE_$cluster_name",                $num_nodes);
        barrier_create("LOGS_CHECKED_$cluster_name",                $num_nodes);
        barrier_create("CHECK_AFTER_FENCING_BEGIN_$cluster_name",   $num_nodes);
        barrier_create("CHECK_AFTER_FENCING_END_$cluster_name",     $num_nodes);
        barrier_create("CHECK_BEFORE_FENCING_BEGIN_$cluster_name",  $num_nodes);
        barrier_create("CHECK_BEFORE_FENCING_END_$cluster_name",    $num_nodes);
        barrier_create("CLUSTER_MD_INIT_$cluster_name",             $num_nodes);
        barrier_create("CLUSTER_MD_CREATED_$cluster_name",          $num_nodes);
        barrier_create("CLUSTER_MD_STARTED_$cluster_name",          $num_nodes);
        barrier_create("CLUSTER_MD_RESOURCE_CREATED_$cluster_name", $num_nodes);
        barrier_create("CLUSTER_MD_CHECKED_$cluster_name",          $num_nodes);
        barrier_create("HAWK_INIT_$cluster_name",                   $num_nodes);
        barrier_create("HAWK_CHECKED_$cluster_name",                $num_nodes);

        # Create barriers for multiple tests
        foreach my $fs_tag ('LUN', 'CLUSTER_MD', 'DRBD_PASSIVE', 'DRBD_ACTIVE') {
            barrier_create("VG_INIT_${fs_tag}_$cluster_name",             $num_nodes);
            barrier_create("PV_VG_LV_CREATED_${fs_tag}_$cluster_name",    $num_nodes);
            barrier_create("VG_RESOURCE_CREATED_${fs_tag}_$cluster_name", $num_nodes);
            barrier_create("VG_RW_CHECKED_${fs_tag}_$cluster_name",       $num_nodes);
            barrier_create("VG_MD5SUM_${fs_tag}_$cluster_name",           $num_nodes);
            barrier_create("FS_INIT_${fs_tag}_$cluster_name",             $num_nodes);
            barrier_create("FS_MKFS_DONE_${fs_tag}_$cluster_name",        $num_nodes);
            barrier_create("FS_GROUP_ADDED_${fs_tag}_$cluster_name",      $num_nodes);
            barrier_create("FS_RESOURCE_STOPPED_${fs_tag}_$cluster_name", $num_nodes);
            barrier_create("FS_DATA_COPIED_${fs_tag}_$cluster_name",      $num_nodes);
            barrier_create("FS_CHECKED_${fs_tag}_$cluster_name",          $num_nodes);
        }
    }

    # Wait for all children to start
    # Children are server/test suites that use the PARALLEL_WITH variable
    wait_for_children_to_start;

    # To synchronise all nodes (including  the support server)
    for my $cluster_infos (split(/,/, get_var('CLUSTER_INFOS'))) {
        # The CLUSTER_INFOS variable for support_server also contains the number of node
        my ($cluster_name, $num_nodes) = split(/:/, $cluster_infos);
        barrier_wait("BARRIER_HA_$cluster_name");
    }
}

1;
# vim: set sw=4 et:
