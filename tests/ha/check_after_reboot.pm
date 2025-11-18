# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check cluster status *after* reboot
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ha/check_after_reboot.pm - Check cluster status after a reboot

=head1 DESCRIPTION

This module is responsible for verifying and restoring the cluster's health after a
node has rebooted, typically as a result of a fencing operation. It performs a
series of checks and recovery actions to ensure the cluster returns to a stable
and operational state.

The key tasks performed by this module include:

=over

=item * Ensuring the correct console is active, especially after a fencing event.

=item * Re-establishing iSCSI connections if they were lost during the reboot.
  Different methods are used for different SLES versions.

=item * Clearing iptables rules in specific QDevice/QNetd scenarios to ensure
  proper network communication after a reboot.

=item * Respecting the SBD start delay to prevent a fenced node from rejoining
  the cluster prematurely.

=item * Verifying the integrity of MD RAID configurations and applying workarounds
  for known issues.

=item * Waiting for all cluster resources to start and then performing a
  comprehensive health check of the entire cluster.

=item * Performing specific checks for SLES for SAP HANA clusters, including
  replication status and takeover handling.

=back

This module is designed following the multi-machine pattern. Its execution is
going to sync with others test modules running in different openQA jobs. The list
of synchronization points is:

=over

=item * C<CHECK_AFTER_REBOOT_BEGIN_${cluster_name}_NODE${node_index}>

=item * C<SBD_START_DELAY_$cluster_name>

=item * C<HANA_RA_RESTART_${cluster_name}_NODE${node_index}>

=item * C<CHECK_AFTER_REBOOT_END_${cluster_name}_NODE${node_index}>

=item * C<HAWK_FENCE_$cluster_name}>

=item * C<QNETD_TESTS_DONE_$cluster_name}>

=back

=head1 VARIABLES

This list only cites variables explicitly used in this module.
Far more variables are used in the base class haclusterbasetest or in lib functions.

=over

=item B<AUTOMATED_REGISTER>

Controls the behavior of HANA resource takeover. If set to 'false', a manual
takeover might be initiated.

=item B<CLUSTER_NAME>

The name of the cluster. This is used for barrier synchronization and other
cluster-wide operations. For SLES for SAP tests, it can also be 'hana' to
trigger specific HANA-related checks.

=item B<HA_CLUSTER_INIT>

If set to 'yes', it indicates that this node is the one that initialized the
cluster. This is used to determine which node was fenced when
B<NODE_TO_FENCE> is not explicitly set.

=item B<HA_UNICAST>

If set, indicates that the cluster is configured to use unicast communication.
This is used in conjunction with B<QDEVICE_TEST_ROLE> to decide whether to
clear iptables.

=item B<HAWKGUI_TEST_ROLE>

If set to 'server', it indicates that this node is part of a HAWK GUI test
scenario. This triggers a wait on a specific barrier to synchronize with the
client-side test.

=item B<HDDVERSION>

If set, indicates that the test is part of an upgrade scenario. This triggers
a workaround for potential network timeout issues.

=item B<NODE_TO_FENCE>

The hostname of the node that was previously fenced. If this variable is not
defined, the module assumes the first node of the cluster (the one with
B<HA_CLUSTER_INIT> set to 'yes') was fenced.

=item B<QDEVICE_TEST_ROLE>

If set to 'client', indicates that the test is part of a QDevice/QNetd
scenario, which may trigger specific cleanup actions (e.g., clearing iptables).

=item B<TAKEOVER_NODE>

Specifies the target node for a HANA resource takeover.

=item B<TIMEOUT_SCALE>

A scaling factor for timeouts. It defaults to 2 and is used to adjust wait
times, especially on slower architectures like ppc64le and aarch64, to
prevent premature test failures.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut


use base 'haclusterbasetest';
use testapi;
use Time::HiRes 'sleep';
use Utils::Architectures;
use lockapi;
use hacluster;
use version_utils qw(is_sle is_sles4sap);
use utils qw(systemctl file_content_replace script_retry);

sub run {
    my $cluster_name = get_cluster_name;
    my $node_to_fence = get_var('NODE_TO_FENCE', undef);
    my $node_index = !defined $node_to_fence ? 1 : 2;
    # In ppc64le and aarch64, workers are slower
    my $timeout_scale = get_var('TIMEOUT_SCALE', 2);
    $timeout_scale = 2 if ($timeout_scale < 2);
    set_var('TIMEOUT_SCALE', $timeout_scale) unless (is_x86_64);

    # Check cluster state *after* reboot
    barrier_wait("CHECK_AFTER_REBOOT_BEGIN_${cluster_name}_NODE${node_index}");

    # We need to be sure to be root and, after fencing, the default console on node01 is not root
    # Only do this on node01, as node02 console is expected to be the root-console
    if ((is_node($node_index) && !get_var('HDDVERSION')) || (is_node(2) && check_var('QDEVICE_TEST_ROLE', 'client'))) {
        reset_consoles;
        select_console 'root-console';
    }
    # This code is also called after boot on update tests. We must ensure to be on the root console
    # in that case
    select_console 'root-console' if (get_var('HDDVERSION'));

    # Workaround network timeout issue during upgrade
    check_iscsi_failure if (get_var('HDDVERSION'));

    # Check iSCSI server is connected
    my $ret = script_run 'ls /dev/disk/by-path/ip-*', $default_timeout;
    if ($ret && is_sle('<16')) {    # iscsi is not connected? reconnect with yast module
        script_run("yast2 iscsi-client; echo yast2-iscsi-client-status-\$? > /dev/$serialdev", 0);
        assert_screen 'iscsi-client-overview-service-tab', $default_timeout;
        send_key 'alt-v';
        wait_still_screen 3;
        assert_screen 'iscsi-client-target-list', $default_timeout;

        if (!check_screen('iscsi-client-target-connected')) {
            # Connects target manually if not automatic
            send_key 'alt-e';
            assert_screen 'iscsi-client-target-startup';
            send_key 'alt-n';
            assert_screen 'iscsi-client-target-connected', $default_timeout;
        }

        send_key 'alt-o';
        wait_still_screen 3;
        wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";
        assert_screen 'root-console', $default_timeout;
        systemctl 'restart pacemaker', timeout => $default_timeout;
    }
    elsif ($ret && is_sle('16+')) {    # iscsi is not connected? restart services to reconnect
        systemctl 'restart iscsi';
        systemctl 'restart iscsid';
        # Check if the iSCSI devices are there. Try 5 times as it can take some seconds
        script_retry('ls /dev/disk/by-path/ip-*', timeout => $default_timeout, retry => 5, delay => 5, fail_message => 'No iSCSI devices!');
        assert_script_run q|sbd -d "$(awk -F= '/^SBD_DEVICE/ {print $2}' /etc/sysconfig/sbd)" list|;
        # Attempt to restart pacemaker up to 5 times.
        # Sometimes it takes some seconds for sbd.service to be able to access the SBD device
        script_retry('systemctl restart pacemaker', timeout => $default_timeout, retry => 5, delay => 5, fail_message => 'Could not restart pacemaker');
        systemctl 'status pacemaker';
    }
    systemctl 'list-units | grep iscsi', timeout => $default_timeout;
    if ((!defined $node_to_fence && check_var('HA_CLUSTER_INIT', 'yes')) || (defined $node_to_fence && get_hostname eq "$node_to_fence")) {
        my $sbd_delay = setup_sbd_delay();
        record_info("SBD delay $sbd_delay sec", "Calculated SBD start delay: $sbd_delay");
        # test should wait longer that startup delay set therefore adding 15s
        sleep $sbd_delay + 15;
    }
    # Barrier for fenced nodes to wait for start delay.
    barrier_wait("SBD_START_DELAY_$cluster_name");

    # Verify if poo#116191 is impacting the job
    my $mdadm_conf = '/etc/mdadm.conf';
    $ret = script_run "test -f $mdadm_conf";
    if (!$ret) {
        # Get UUID from the devices. blkdid output for the UUID is different than
        # the format in /etc/mdadm.conf, so strip all non hex characters from it and
        # then, split in 4 parts and join with ':', which should produce the format
        # in /etc/mdadm.conf
        my $get_uuid_cmd = 'for bd in $(grep ^DEVICE ' . $mdadm_conf . '); do [[ "$bd" == "DEVICE" ]] && continue; ';
        $get_uuid_cmd .= 'blkid -o export "$bd" | sed -n -e s/[\-:]//g -e /^UUID=/s/^UUID=//p; done | sort -u';
        my $uuid = script_output $get_uuid_cmd;
        # filter out the noise in the output of openQA script_output API
        $uuid =~ s/(^\[.*$)|(\n)//mg;
        $uuid = join(':', substr($uuid, 0, 8), substr($uuid, 8, 8), substr($uuid, 16, 8), substr($uuid, 24));
        die 'MD RAID devices have different UUIDs!' if ($uuid =~ /\n/);
        my $mdadm_uuid = script_output "sed -r -n -e '/ARRAY/s/.*UUID=([0-9a-z:]+).*/\\1/p' $mdadm_conf";
        if ($uuid ne $mdadm_uuid) {
            record_soft_failure 'poo#116191 -- MD RAID UUID is different in /etc/mdadm.conf and cluster_md devices';
            record_info 'UUID on MD Devices', $uuid;
            record_info 'mdadm.conf', script_output "cat $mdadm_conf";
            # Apply workaround in node 1, sync with rest of the cluster and cleanup cluster_md resource
            if (is_node(1)) {
                file_content_replace($mdadm_conf, 'UUID=[a-z0-9:]+' => "UUID=$uuid");
                exec_csync;
                rsc_cleanup 'cluster_md';
            }
        }
    }

    # Record pacemaker status
    systemctl 'status pacemaker', timeout => $default_timeout;

    # Remove iptable rules in node 1 when testing qnetd/qdevice in multicast
    assert_script_run "iptables -F && iptables -X" if (is_node(1) && check_var('QDEVICE_TEST_ROLE', 'client') && !get_var('HA_UNICAST'));
    # Wait for resources to be started
    if (is_sles4sap) {
        if (check_var('CLUSTER_NAME', 'hana') && check_var('AUTOMATED_REGISTER', 'false')) {
            my $takeover_node = get_var('TAKEOVER_NODE');
            if ($takeover_node ne get_hostname) {
                check_cluster_state(proceed_on_failure => 1);
                'sles4sap'->do_hana_takeover(node => $takeover_node, cluster => 1);
            }
        }
        barrier_wait("HANA_RA_RESTART_${cluster_name}_NODE${node_index}") if check_var('CLUSTER_NAME', 'hana');
        wait_until_resources_started(timeout => 900);
    } else {
        wait_until_resources_started(timeout => 900);
    }

    # And check for the state of the whole cluster
    check_cluster_state;

    crm_list_options;

    if (check_var('CLUSTER_NAME', 'hana')) {
        'sles4sap'->check_replication_state;
        'sles4sap'->check_hanasr_attr;
        save_screenshot;
    }

    # Synchronize all nodes
    barrier_wait("CHECK_AFTER_REBOOT_END_${cluster_name}_NODE${node_index}");
    # Note: the following barriers aren't supposed to be used in multiple fencing tests
    barrier_wait("HAWK_FENCE_$cluster_name") if (check_var('HAWKGUI_TEST_ROLE', 'server'));
    barrier_wait("QNETD_TESTS_DONE_$cluster_name") if (check_var('QDEVICE_TEST_ROLE', 'client'));

    # In case of HANA cluster we also have to test the failback/takeback after the first fencing
    # Note: should be done here and not in fencing.pm, as cluster needs to be healthy before
    if (check_var('CLUSTER_NAME', 'hana') && !defined $node_to_fence) {
        set_var('NODE_TO_FENCE', choose_node(2));
    }
}

1;
