# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ha-cluster-bootstrap
# Summary: shutdown a cluster gracefully and start it up again using "crm cluster" commands
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use version_utils 'is_sle';
use utils;

sub run {
    die "Graceful cluster shutdown option --all was only introduced with SLE15 SP4" if (is_sle('<15-sp4'));

    my $cluster_name = get_cluster_name;
    my $crm_timeout = bmwqemu::scale_timeout(60);

    # Waiting for the other nodes to be ready
    barrier_wait("CLUSTER_GRACEFUL_SHUTDOWN_" . "$cluster_name");

    # graceful shutdown
    assert_script_run("crm cluster stop --all", $crm_timeout) if is_node(1);

    wait_until_resources_stopped;

    # confirm cluster is stopped (only needed for logging purposes)
    record_info('corosync', 'check if corosync is stopped');
    validate_script_output_retry("systemctl --no-pager -l status corosync", sub { m/Stopped Corosync/i });
    record_info('pacemaker', 'check if pacemaker is stopped');
    validate_script_output_retry("systemctl --no-pager -l status pacemaker", sub { m/Stopped Pacemaker/i });

    # start the cluster, when all nodes are in sync
    assert_script_run("crm cluster start --all", $crm_timeout) if is_node(1);

    wait_until_resources_started;

    # confirm cluster suite is started (only needed for logging purposes)
    record_info('corosync', 'check if corosync is started');
    validate_script_output_retry("systemctl --no-pager -l status corosync", sub { m/Active: active \(running\)/i });
    record_info('pacemaker', 'check if pacemaker is started');
    validate_script_output_retry("systemctl --no-pager -l status pacemaker", sub { m/Active: active \(running\)/i });
    record_info('crm_mon', 'check crm_mon output');
    validate_script_output_retry("$crm_mon_cmd", sub { m/No inactive resources/i });

    save_state;
}

1;
