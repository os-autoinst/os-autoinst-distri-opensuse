# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: chrony ntp corosync-qdevice ha-cluster-bootstrap
# Summary: Add node to existing cluster
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use lockapi;
use hacluster;
use utils qw(zypper_call);

sub wait_for_password_prompt {
    my %args = @_;
    $args{timeout} //= $default_timeout;
    $args{failok} //= 0;
    die((caller(0))[3] . ' expects a needle tag or ref in the "needle => $tag" arg') unless $args{needle};
    if (is_serial_terminal()) {
        die "Timed out while waiting for password prompt" unless (wait_serial(qr/Password:\s*$/i));
    }
    elsif ($args{failok}) {
        return (check_screen $args{needle}, $args{timeout});
    }
    else {
        assert_screen $args{needle}, $args{timeout};
    }
}

sub run {
    my $cluster_name = get_cluster_name;
    my $node_to_join = get_node_to_join;

    # Qdevice configuration
    if (get_var('QDEVICE')) {
        zypper_call 'in corosync-qdevice';
        barrier_wait("QNETD_SERVER_READY_$cluster_name");
    }

    # Ensure that ntp service is activated/started
    activate_ntp;

    # Wait until cluster is initialized
    diag 'Wait until cluster is initialized...';
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Try to join the HA cluster through first node
    assert_script_run "ping -c1 $node_to_join";
    # Status redirection is not needed if running on serial terminal
    my $redirection = is_serial_terminal() ? '' : "> /dev/$serialdev";
    enter_cmd "ha-cluster-join -yc $node_to_join ; echo ha-cluster-join-finished-\$? $redirection";
    wait_for_password_prompt(needle => 'ha-cluster-join-password', timeout => $join_timeout);
    type_password;
    send_key 'ret';
    if (check_var('TWO_NODES', 'no') && wait_for_password_prompt(needle => 'ha-cluster-join-3nodes-password', timeout => 150, failok => 1)) {
        type_password;
        send_key 'ret';
    }
    my $join_success = wait_serial("ha-cluster-join-finished-0", 120);
    unless ($join_success) {
        record_info "Join Failed", "HA cluster join failed. Waiting 3 seconds and re-trying";
        sleep bmwqemu::scale_timeout(3);
        # Attempt to start pacemaker in case this was what failed during join
        # This is needed so ha-cluster-remove works
        assert_script_run 'systemctl start pacemaker';
        assert_script_run 'ha-cluster-remove -F -y -c $(hostname)';
        assert_script_run "ha-cluster-join -yc $node_to_join", 120;
    }

    # Indicate that the other nodes have joined the cluster
    barrier_wait("NODE_JOINED_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
