# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh ha-cluster-bootstrap corosync-qdevice
# Summary: Create HA cluster using crm cluster init
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use serial_terminal qw(select_serial_terminal);
use hacluster;
use utils qw(zypper_call clear_console file_content_replace);
use version_utils qw(is_sle package_version_cmp);

sub type_qnetd_pwd {
    if (wait_serial(qr/Password:\s*$/i)) {
        type_password;
        send_key 'ret';
        return;
    }
    die "Timed out while waiting for password prompt from QNetd server";
}

sub cluster_init {
    my ($init_method, $fencing_opt, $unicast_opt, $qdevice_opt) = @_;

    record_info 'cluster_init', "Initializing cluster with: -y $fencing_opt $unicast_opt $qdevice_opt";
    if ($init_method eq 'crm-cluster-init') {
        enter_cmd "crm cluster init -y $fencing_opt $unicast_opt $qdevice_opt ; echo cluster-init-finished-\$?";
        type_qnetd_pwd if get_var('QDEVICE');
    }
    elsif ($init_method eq 'crm-debug-mode') {
        enter_cmd "crm -dR cluster init -y $fencing_opt $unicast_opt $qdevice_opt ; echo cluster-init-finished-\$?";
        type_qnetd_pwd if get_var('QDEVICE');
        if (!wait_serial("cluster-init-finished-0", $join_timeout)) {
            # cluster init failed in debug mode. Wait some seconds and attempt to start pacemaker
            # in case this was due to a transient error
            sleep bmwqemu::scale_timeout(3);
            assert_script_run 'systemctl start pacemaker';
            assert_script_run 'systemctl --no-pager status pacemaker';
        }
    }
}

sub run {
    select_serial_terminal;

    # Validate cluster creation with crm cluster init tool
    my $cluster_name = get_cluster_name;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $sbd_device = get_lun;
    my $sbd_cfg = '/etc/sysconfig/sbd';
    my $unicast_arg = is_sle('>=16') ? '--transport udpu' : '-u';
    my $unicast_opt = get_var("HA_UNICAST") ? $unicast_arg : '';
    my $quorum_policy = 'stop';
    my $fencing_opt = "-s \"$sbd_device\"";
    my $qdevice_opt = '';

    # HA test modules use packages from ClusterTools2. Attempt to install it here and in
    # ha_cluster_join, but continue if it's not possible (retval 104)
    zypper_call('in ClusterTools2', exitcode => [0, 104]);

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
    cluster_init('crm-cluster-init', $fencing_opt, $unicast_opt, $qdevice_opt);

    # If we failed to initialize the cluster with 'crm cluster init', try again with crm in debug mode
    cluster_init('crm-debug-mode', $fencing_opt, $unicast_opt, $qdevice_opt) if (!wait_serial("cluster-init-finished-0", $join_timeout));

    # Configure SBD_DELAY_START to yes
    # This may be necessary if your cluster nodes reboot so fast that the
    # other nodes are still waiting in the fence acknowledgement phase.
    # This is an occasional issue with virtual machines.
    # In case of newer SLES (15SP4+), it performs better leaving it on default values.
    if (is_sle('<15-SP4')) {
        record_info("SBD_DELAY_START set to YES");
        file_content_replace("$sbd_cfg", "SBD_DELAY_START=.*" => "SBD_DELAY_START=yes");
    }

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
        my $count = 5;
        my $sbd_output = 0;
        my $clear_count = 0;
        while ($count--) {
            $sbd_output = script_output("sbd -d \"$sbd_device\" list");
            # Check if all the nodes have sbd started and ready
            if (get_node_number == ($clear_count = () = $sbd_output =~ /\sclear\s|\sclear$/g)) {
                last;
            }
            elsif (!$count) {
                die "Unexpected node count in sdb list command output";
            }
            sleep 2;
            record_info('Retry');
        }
    }

    # Check if the multicast port is correct (should be 5405 or 5407 by default)
    my $corosync_ver = script_output(q|rpm -q --qf '%{VERSION}\n' corosync|);
    record_info('corosync version', $corosync_ver);

    # On corosync >= 3.1.9 the mcast port is not explicitly stated in /etc/corosync/corosync.conf
    # So only test for it on older versions
    my $cmp_result = package_version_cmp($corosync_ver, '3.1.9');
    assert_script_run "grep -Eq '^[[:blank:]]*mcastport:[[:blank:]]*(5405|5407)[[:blank:]]*' $corosync_conf" if ($cmp_result < 0);

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
