# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh corosync-qnetd
# Summary: Test qdevice/qnetd
# qdevice/qnetd is a supported feature since 15-SP1
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(choose_node
  $default_timeout
  ensure_resource_running
  get_cluster_name
  get_ip
  is_node
  prepare_console_for_fencing
  save_state
  wait_for_idle_cluster
  wait_until_resources_started
);
use utils qw(zypper_call exec_and_insert_password);
use version_utils qw(is_sle);
use Utils::Logging qw(record_avc_selinux_alerts);

sub handle_diskless_sbd_scenario_cluster_node {
    my $cluster_name = get_cluster_name;
    if (get_var('USE_DISKLESS_SBD') && !check_var('QDEVICE_TEST_ROLE', 'qnetd_server')) {
        barrier_wait("DISKLESS_SBD_QDEVICE_$cluster_name");
        assert_script_run 'crm cluster restart';
        wait_until_resources_started;
        wait_for_idle_cluster;
    }
}

sub qdevice_status {
    my ($expected_status) = @_;
    my $num_nodes = get_required_var('NUM_NODES');
    my $quorum_status_cmd = 'crm corosync status quorum';
    my $qnetd_status_cmd = 'crm corosync status qnetd';
    my $output;

    $num_nodes-- if ($expected_status eq 'stopped');

    # We have to enable ssh passwordless between qnetd server and node2
    # But from 15-SP6 Build83.1 the qdevice "Add all nodes' keys to qnetd authorized_keys"
    if (is_sle('<15-SP6')) {
        exec_and_insert_password($qnetd_status_cmd) if is_node(2);
    }

    # Check qdevice status
    $output = script_output "$qnetd_status_cmd" if ($expected_status ne 'stopped');
    die "Heuristics script for quorum is failing in all nodes" if ($expected_status =~ /^split-brain/ && $output !~ /Heuristics:\s+Pass\s/);

    $output = script_output "$quorum_status_cmd";

    # Check split brain situation
    if ($expected_status eq 'split-brain-blocked') {
        die "Unexpected output for split-brain situation" unless ($output =~ /Activity blocked/ && $output =~ /Quorate:\s+No/);
        return;
    }

    my @regexps = map { $_ . ($num_nodes + 1) } ('Expected votes:\s+', 'Highest expected:\s+');
    my $total_votes = ($expected_status eq 'split-brain-check') ? $num_nodes : $num_nodes + 1;
    push @regexps, 'Total votes:\s+' . $total_votes;
    push @regexps, 'Quorum:\s+' . $num_nodes;

    push @regexps, 'Flags:\s+Quorate\s+Qdevice' if ($expected_status eq 'started' || $expected_status eq 'split-brain-check');
    push @regexps, 'Flags:\s+2Node\s+Quorate' if ($expected_status eq 'stopped');

    die "Qdevice membership information does not match expected info" if ($expected_status eq 'started' && $output !~ /\s+0\s+1\s+Qdevice/);
    die "Qdevice membership information shown when stopped" if ($expected_status eq 'stopped' && $output =~ /\s+0\s+1\s+Qdevice/);

    foreach my $exp (@regexps) { die "Unexpected output. Output does not match [$exp]" unless ($output =~ /$exp/) }
}

sub run {
    my $cluster_name = get_cluster_name;
    my $qdevice_check = "/etc/corosync/qdevice/check_master.sh";

    # As this module causes a fence operation, we need to prepare the console for assert_screen
    # on grub2 and bootmenu
    prepare_console_for_fencing;

    # iptables is not installed in SLE 16 by default
    zypper_call 'in iptables' if is_sle('>=16');

    if (check_var('QDEVICE_TEST_ROLE', 'qnetd_server')) {
        zypper_call 'in corosync-qnetd';
        barrier_wait("QNETD_SERVER_READY_$cluster_name");
    }
    else {
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/qdevice_check_master.sh -o $qdevice_check";
        assert_script_run "chmod +x $qdevice_check";
    }

    if (is_node(1)) {
        my $qnet_node_host = choose_node(3);
        my $qnet_node_ip = get_ip($qnet_node_host);

        # Add a promotable resource to check if the current node is hosting
        # master instance of the resource. If so, this cluster partition
        # is preferred to be given the vote from qnetd.
        assert_script_run "EDITOR=\"sed -ie '\$ a primitive stateful-1 ocf:pacemaker:Stateful'\" crm configure edit";
        assert_script_run "EDITOR=\"sed -ie '\$ a clone promotable-1 stateful-1 meta promotable=true'\" crm configure edit";
        save_state;

        # Qdevice should be started
        qdevice_status('started');

        # Remove qdevice
        assert_script_run "crm cluster remove --qdevice -y";
        # Qdevice should be stopped
        qdevice_status('stopped');

        # Add qdevice to a running cluster with heuristic check
        assert_script_run "crm cluster init qdevice --qnetd-hostname=$qnet_node_ip -y --qdevice-heuristics=/etc/corosync/qdevice/check_master.sh --qdevice-heuristics-mode=on";
        handle_diskless_sbd_scenario_cluster_node;
        # Qdevice should be started again
        qdevice_status('started');

        # Ensure promotable resource is in node 1
        script_run 'crm resource move promotable-1 ' . choose_node(1);
    }
    else {
        handle_diskless_sbd_scenario_cluster_node;
    }

    # Perform Split Brain test
    barrier_wait("SPLIT_BRAIN_TEST_READY_$cluster_name");

    record_info('Split-brain info', 'Split brain test');

    record_info('Disabling stonith', 'Disable stonith to prevent fencing of node before our check');
    assert_script_run 'crm configure property stonith-enabled="false"' if is_node(1);
    # Add firewall rules to provoke a split brain situation and confirm that
    # the qdevice node gives its vote to the node1 (where the master resource is running)
    # Firewall rules go in both nodes in multicast cluster, and only in node 2 in unicast
    barrier_wait("QNETD_STONITH_DISABLED_$cluster_name");
    my $partner_ip = is_node(1) ? get_ip(choose_node(2)) : get_ip(choose_node(1));
    assert_script_run "iptables -A INPUT -s $partner_ip -j DROP; iptables -A OUTPUT -d $partner_ip -j DROP"
      if ((is_node(1) && !get_var('HA_UNICAST')) || is_node(2));
    sleep $default_timeout;

    if (is_node(2) && !get_var('USE_DISKLESS_SBD')) {
        # Activity must be blocked in node2 due to split brain situation
        record_info('Split-brain check', 'Check if activity is blocked');
        qdevice_status('split-brain-blocked');
    }
    elsif (is_node(1)) {
        # Node 1 must be OK, but with fewer Expected Votes
        record_info('Split-brain check', 'Check qdevice information in node 1');
        qdevice_status('split-brain-check');
        # Resource must be running in this node
        my $node_01 = choose_node(1);
        ensure_resource_running("promotable-1", ":[[:blank:]]*$node_01\[[:blank:]]*[Mm]aster\$");
    }

    barrier_wait("SPLIT_BRAIN_TEST_DONE_$cluster_name");

    # Show cluster status before ending the test
    save_state if (is_node(1) || !(get_var('USE_DISKLESS_SBD') || check_var('QDEVICE_TEST_ROLE', 'qnetd_server')));

    # Restart stonith. This should fence node 2
    assert_script_run 'crm configure property stonith-enabled="true"' if is_node(1);

    barrier_wait("QNETD_SERVER_DONE_$cluster_name");

    # The following barrier prevents the QNetd server from stopping before the cluster nodes complete their tests
    barrier_wait("QNETD_TESTS_DONE_$cluster_name") if check_var('QDEVICE_TEST_ROLE', 'qnetd_server');
}

# Avoid calling hacluster::post_run_hook(). It will fail on node 2 which gets fenced
# But collect SELinux AVCs on node 1 and server
sub post_run_hook {
    my ($self) = @_;
    record_avc_selinux_alerts() if (is_sle('16+') && !is_node(2));
}

1;
