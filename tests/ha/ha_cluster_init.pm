# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh ha-cluster-bootstrap corosync-qdevice
# Summary: Create HA cluster using ha-cluster-init
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

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
    # No need to send status to serial terminal if running on serial terminal
    my $redirection = is_serial_terminal() ? '' : "> /dev/$serialdev";

    if ($init_method eq 'ha-cluster-init') {
        enter_cmd "ha-cluster-init -y $fencing_opt $unicast_opt $qdevice_opt ; echo ha-cluster-init-finished-\$? $redirection";
        type_qnetd_pwd if get_var('QDEVICE');
    }
    elsif ($init_method eq 'crm-debug-mode') {
        enter_cmd "crm -dR cluster init -y $fencing_opt $unicast_opt $qdevice_opt ; echo ha-cluster-init-finished-\$? $redirection";
        type_qnetd_pwd if get_var('QDEVICE');
        if (!wait_serial("ha-cluster-init-finished-0", $join_timeout)) {
            # ha-cluster-init failed in debug mode. Wait some seconds and attempt to start pacemaker
            # in case this was due to a transient error
            sleep bmwqemu::scale_timeout(3);
            assert_script_run 'systemctl start pacemaker';
            assert_script_run 'systemctl --no-pager status pacemaker';
        }
    }
}

sub run {
    # Validate cluster creation with ha-cluster-init tool
    my $cluster_name = get_cluster_name;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $sbd_device = get_lun;
    my $sbd_cfg = '/etc/sysconfig/sbd';
    my $unicast_opt = get_var("HA_UNICAST") ? '-u' : '';
    my $quorum_policy = 'stop';
    my $fencing_opt = "-s \"$sbd_device\"";
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


    # Initialize the cluster with diskless or shared storage SBD (default)
    $fencing_opt = '-S' if (get_var('USE_DISKLESS_SBD'));
    cluster_init('ha-cluster-init', $fencing_opt, $unicast_opt, $qdevice_opt);

    # If we failed to initialize the cluster with 'ha-cluster-init', trying again with crm in debug mode
    cluster_init('crm-debug-mode', $fencing_opt, $unicast_opt, $qdevice_opt) if (!wait_serial("ha-cluster-init-finished-0", $join_timeout));

    # Configure SBD_DELAY_START to yes
    # This may be necessary if your cluster nodes reboot so fast that the
    # other nodes are still waiting in the fence acknowledgement phase.
    # This is an occasional issue with virtual machines.
    #file_content_replace("$sbd_cfg", "SBD_DELAY_START=.*" => "SBD_DELAY_START=yes");

    # Execute csync2 to synchronise the sysconfig sbd file
    exec_csync;

    # Set wait_for_all option to 0 if we are in a two nodes cluster situation
    # We need to set it for reproducing the same behaviour we had with no-quorum-policy=ignore
    if (!check_var('TWO_NODES', 'no')) {
        record_info("Cluster info", "Two nodes cluster detected");
        wait_for_idle_cluster;
        assert_script_run "crm corosync set quorum.wait_for_all 0";
        assert_script_run "grep -q 'wait_for_all: 0' $corosync_conf";
        assert_script_run "crm cluster stop";
        assert_script_run "crm cluster start";
        wait_until_resources_started;
    }

    # Signal that the cluster stack is initialized
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Waiting for the other nodes to join
    diag 'Waiting for other nodes to join...';
    barrier_wait("NODE_JOINED_$cluster_name");

    # Execute csync2 to synchronise the configuration files
    exec_csync;

    # State of SBD if shared storage SBD is used
    if (!get_var('USE_DISKLESS_SBD')) {
        my $sbd_output = script_output("sbd -d \"$sbd_device\" list");
        # Check if all the nodes have sbd started and ready
        die "Unexpected node count in sdb list command output"
          if (get_node_number != (my $clear_count = () = $sbd_output =~ /\sclear\s|\sclear$/g));
    }

    # Check if the multicast port is correct (should be 5405 or 5407 by default)
    assert_script_run "grep -Eq '^[[:blank:]]*mcastport:[[:blank:]]*(5405|5407)[[:blank:]]*' $corosync_conf";

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
