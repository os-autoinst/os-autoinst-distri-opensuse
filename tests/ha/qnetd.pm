# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test qdevice/qnetd
# qdevice/qnetd is a supported feature since 15-SP1
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use version_utils 'is_sle';
use utils qw(systemctl file_content_replace zypper_call);

sub qdevice_status {
    my ($expected_status) = @_;
    my $num_nodes         = get_required_var('NUM_NODES');
    my $quorum_status_cmd = 'crm corosync status quorum';
    my $qnetd_status_cmd  = 'crm corosync status qnetd';
    my $output;

    $num_nodes-- if ($expected_status eq 'stopped');

    # Check qdevice status
    script_run "$qnetd_status_cmd";

    $output = script_output("$quorum_status_cmd");

    # Check split brain situation
    if ($expected_status eq 'split-brain') {
        die "Unexpected output for split-brain situation" unless ($output =~ /Activity blocked/);
        return;
    }

    my @regexps = map { $_ . ($num_nodes + 1) } ('Expected votes:\s+', 'Highest expected:\s+', 'Total votes:\s+');
    push @regexps, 'Quorum:\s+' . $num_nodes;

    push @regexps, 'Flags:\s+Quorate\s+Qdevice' if ($expected_status eq 'started');
    push @regexps, 'Flags:\s+2Node\s+Quorate'   if ($expected_status eq 'stopped');

    die "Qdevice membership information does not match expected info" if ($expected_status eq 'started' and $output !~ /\s+0\s+1\s+Qdevice/);
    die "Qdevice membership information shown when stopped"           if ($expected_status eq 'stopped' and $output =~ /\s+0\s+1\s+Qdevice/);

    foreach my $exp (@regexps) { die "Unexpected output. Output does not match [$exp]" unless ($output =~ /$exp/) }
}

sub run {
    my $cluster_name  = get_cluster_name;
    my $qdevice_check = "/etc/corosync/qdevice/check_master.sh";

    if (check_var('QDEVICE_TEST_ROLE', 'qnetd_server')) {
        zypper_call 'in corosync-qnetd';
        barrier_wait("QNETD_SERVER_READY_$cluster_name");
    }
    else {
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/qdevice_check_master.sh -o $qdevice_check";
    }

    if (is_node(1)) {
        my $qnet_node_host = choose_node(3);
        my $qnet_node_ip   = get_ip($qnet_node_host);
        my $node2_ip       = get_ip(choose_node(2));

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
        # Qdevice should be started again
        qdevice_status('started');

        # Add firewall rules to provoke a split brain situation and confirm that
        # the qdevice node gives its vote to the node1 (where the master resource is running)
        record_info('Split-brain info', 'Split brain test');
        assert_script_run "iptables -A INPUT -s $node2_ip -j DROP; iptables -A OUTPUT -d $node2_ip -j DROP";
        sleep $default_timeout;
    }

    barrier_wait("SPLIT_BRAIN_TEST_$cluster_name");

    # Activity must be blocked in node2 due to split brain situation
    if (is_node(2)) {
        record_info('Split-brain check', 'Check if activity is blocked');
        qdevice_status('split-brain');
    }

    # Show cluster status before ending the test
    save_state if (!check_var('QDEVICE_TEST_ROLE', 'qnetd_server'));

    barrier_wait("QNETD_SERVER_DONE_$cluster_name");
}

1;
