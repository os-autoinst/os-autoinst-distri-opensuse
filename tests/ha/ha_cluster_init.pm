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
use testapi qw(is_serial_terminal :DEFAULT);
use lockapi;
use hacluster;
use utils qw(zypper_call clear_console file_content_replace);

sub type_qnetd_pwd {
    if (is_serial_terminal()) {
        if (wait_serial(qr/Password:\s*$/i)) {
            type_password;
            send_key 'ret';
        }
        else {
            die "Timed out while waiting for password prompt from QNetd server";
        }
    }
    else {
        assert_screen('password-prompt', 60);
        type_password;
        send_key 'ret';
    }
}

sub cluster_init {
    my ($init_method, $fencing_opt, $unicast_opt, $qdevice_opt) = @_;

    # Clear the console to correctly catch the password needle if needed
    clear_console if !is_serial_terminal();

    if ($init_method eq 'ha-cluster-init') {
        type_string "ha-cluster-init -y $fencing_opt $unicast_opt $qdevice_opt ; echo ha-cluster-init-finished-\$? > /dev/$serialdev\n";
        type_qnetd_pwd if get_var('QDEVICE');
    }
    elsif ($init_method eq 'crm-debug-mode') {
        type_string "crm -dR cluster init -y $fencing_opt $unicast_opt $qdevice_opt ; echo ha-cluster-init-finished-\$? > /dev/$serialdev\n";
        type_qnetd_pwd                      if get_var('QDEVICE');
        die "Cluster initialization failed" if (!wait_serial("ha-cluster-init-finished-0", $join_timeout));
    }
}

sub run {
    # Validate cluster creation with ha-cluster-init tool
    my $cluster_name  = get_cluster_name;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $sbd_device    = get_lun;
    my $sbd_cfg       = '/etc/sysconfig/sbd';
    my $unicast_opt   = get_var("HA_UNICAST") ? '-u' : '';
    my $quorum_policy = 'stop';
    my $fencing_opt   = "-s \"$sbd_device\"";
    my $qdevice_opt;

    # Qdevice configuration
    if (get_var('QDEVICE')) {
        zypper_call 'in corosync-qdevice';
        my $qnet_node_host = choose_node(3);
        $qdevice_opt = "--qnetd-hostname=" . get_ip($qnet_node_host);
        barrier_wait("QNETD_SERVER_READY_$cluster_name");
    }

    # Ensure that ntp service is activated/started
    activate_ntp;

    # Configure SBD_DELAY_START to yes
    # This may be necessary if your cluster nodes reboot so fast that the
    # other nodes are still waiting in the fence acknowledgement phase.
    # This is an occasional issue with virtual machines.
    file_content_replace("$sbd_cfg", "SBD_DELAY_START=no" => "SBD_DELAY_START=yes");

    # Initialize the cluster with diskless or shared storage SBD (default)
    $fencing_opt = '-S' if (get_var('USE_DISKLESS_SBD'));
    cluster_init('ha-cluster-init', $fencing_opt, $unicast_opt, $qdevice_opt);

    # If we failed to initialize the cluster with 'ha-cluster-init', trying again with crm in debug mode
    cluster_init('crm-debug-mode', $fencing_opt, $unicast_opt, $qdevice_opt) if (!wait_serial("ha-cluster-init-finished-0", $join_timeout));

    # Signal that the cluster stack is initialized
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Waiting for the other nodes to join
    diag 'Waiting for other nodes to join...';
    barrier_wait("NODE_JOINED_$cluster_name");

    # We need to configure the quorum policy according to the number of nodes
    $quorum_policy = 'ignore' if (get_node_number == 2) && !get_var('QDEVICE');
    assert_script_run "crm configure property no-quorum-policy=$quorum_policy";

    # Execute csync2 to synchronise the configuration files
    exec_csync;

    # State of SBD if shared storage SBD is used
    if (!get_var('USE_DISKLESS_SBD')) {
        my $sbd_output = script_output("sbd -d \"$sbd_device\" list");
        record_soft_failure 'bsc#1170037 - All nodes not shown by sbd list command'
          if (get_node_number != (my $clear_count = () = $sbd_output =~ /\sclear\s|\sclear$/g));
    }

    # Check if the multicast port is correct (should be 5405 or 5407 by default)
    assert_script_run "grep -Eq '^[[:blank:]]*mcastport:[[:blank:]]*(5405|5407)[[:blank:]]*' $corosync_conf";

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
