# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialize barriers used in ENSA cluster tests
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use hacluster qw(get_cluster_info);

sub create_general_ha_barriers {
    my $cluster_name = get_cluster_info()->{cluster_name};
    my $num_nodes = get_cluster_info()->{num_nodes};

    # Barrier to let the nodes begin after the supportserver configuration is done
    barrier_create("BARRIER_HA_$cluster_name", $num_nodes + 1);
    # Barriers used during the test
    barrier_create("CLUSTER_INITIALIZED_$cluster_name", $num_nodes);
    barrier_create("NODE_JOINED_$cluster_name", $num_nodes);
    barrier_create("NW_CLUSTER_HOSTS_$cluster_name", $num_nodes);
    barrier_create("NFS_MOUNTS_READY_$cluster_name", $num_nodes);
    barrier_create("LOGS_CHECKED_$cluster_name", $num_nodes);
}

# Creates the barriers that are specific to the ENSA2 test sequence
sub create_ensa_only_barriers {
    # Netweaver stack installation barriers
    # Installation flow:
    # ASCS: |--install progress-->
    # ERS:  |___wait for ASCS____|--install progress-->
    # DB:   |____________waits for ASCS (ERS)__________|--install progress-->
    # PAS   |___________________waits for DB_________________________________|--install progress-->
    # AAS   |___________________waits for PAS______________________________________________________|--install progress-->

    if (get_var('SAP_INSTANCES')) {
        my @instances = split(',', get_var('SAP_INSTANCES'));
        my $no_of_instances = @instances;
        record_info('Instances no', $no_of_instances);
        my %wait_times = (
            ASCS => $no_of_instances,    # everything waits for ASCS
            ERS => $no_of_instances - 1,    # everything but ASCS waits for ERS
            HDB => grep('ERS', @instances) == 1 ? $no_of_instances - 2 : $no_of_instances - 1,    # Everything but ASCS (optionally ERS) waits for HDB
        );
        $wait_times{PAS} = $wait_times{HDB} - 1;    # PAS waits for HDB = same time -1. Only AAS waits for PAS

        for my $instance_type (@instances) {
            next() if ($wait_times{$instance_type} <= 1);    # Do not raise barrier for single instance
            barrier_create("SAPINST_$instance_type", $wait_times{$instance_type});
        }
        barrier_create('SAPINST_INSTALLATION_FINISHED', $no_of_instances);
        barrier_create('SAPINST_SYNC_NODES', $no_of_instances);
        barrier_create('ENSA_CLUSTER_SETUP', $no_of_instances);
        barrier_create('ENSA_CLUSTER_CONNECTOR_SETUP_DONE', $no_of_instances);
        barrier_create('ENSA_TEST_END', $no_of_instances);
        barrier_create('ENSA_FAILOVER_DONE', '2');
        barrier_create('ENSA_ORIGINAL_STATE', '2');
        barrier_create('ISCSI_LUN_PREPARE', '2');    #only ASCS/ERS need that
    }
}

sub run {
    my $cluster_info = get_cluster_info();
    die 'The module requires at least two nodes.' if (get_cluster_info()->{num_nodes} < 2);
    if (get_var('HOSTNAME', '') =~ /node01$/ and !get_var('USE_SUPPORT_SERVER')) {
        die 'The module is currently only able to run on a supportserver';
    }

    create_general_ha_barriers();
    create_ensa_only_barriers();

    # Wait for all children to start
    # Children are server/test suites that use the PARALLEL_WITH variable
    wait_for_children_to_start();
}

1;
