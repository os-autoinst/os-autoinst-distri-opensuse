# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-iscsi-client pacemaker-cli
# Summary: Check cluster status *after* reboot
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Time::HiRes 'sleep';
use Utils::Architectures;
use lockapi;
use hacluster;
use version_utils qw(is_sles4sap);
use utils qw(systemctl file_content_replace);

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

    # Remove iptable rules in node 1 when testing qnetd/qdevice in multicast
    assert_script_run "iptables -F && iptables -X" if (is_node(1) && check_var('QDEVICE_TEST_ROLE', 'client') && !get_var('HA_UNICAST'));

    # Workaround network timeout issue during upgrade
    if (get_var('HDDVERSION')) {
        assert_script_run 'journalctl -b --no-pager -o short-precise > bsc1129385-check-journal.log';
        my $iscsi_fails = script_run 'grep -q "iscsid: cannot make a connection to" bsc1129385-check-journal.log';
        my $csync_fails = script_run 'grep -q "corosync.service: Failed" bsc1129385-check-journal.log';
        my $pcmk_fails = script_run 'egrep -q "pacemaker.service.+failed" bsc1129385-check-journal.log';

        if (defined $iscsi_fails and $iscsi_fails == 0 and defined $csync_fails
            and $csync_fails == 0 and defined $pcmk_fails and $pcmk_fails == 0)
        {
            record_soft_failure "bsc#1129385";
            upload_logs 'bsc1129385-check-journal.log';
            $iscsi_fails = script_run 'grep -q LIO-ORG /proc/scsi/scsi';
            systemctl 'restart iscsi' if ($iscsi_fails);
            systemctl 'restart pacemaker';
        }
    }

    # Check iSCSI server is connected
    my $ret = script_run 'ls /dev/disk/by-path/ip-*', $default_timeout;
    if ($ret) {    # iscsi is not connected?
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
    systemctl 'list-units | grep iscsi', timeout => $default_timeout;

    if ((!defined $node_to_fence && check_var('HA_CLUSTER_INIT', 'yes')) || (defined $node_to_fence && get_hostname eq "$node_to_fence")) {
        my $sbd_delay = calculate_sbd_start_delay;
        record_info("SBD delay $sbd_delay sec", "Calculated SBD start delay: $sbd_delay");
        sleep $sbd_delay;
    }
    # Barrier for fenced nodes to wait for start delay.
    barrier_wait("SBD_START_DELAY_$cluster_name");

    # Verify if poo#116191 is impacting the job
    my $mdadm_conf = '/etc/mdadm.conf';
    # Get UUID from the devices. blkdid output for the UUID is different than
    # the format in /etc/mdadm.conf, so strip all non hex characters from it and
    # then, split in 4 parts and join with ':', which should produce the format
    # in /etc/mdadm.conf
    my $get_uuid_cmd = 'for bd in $(grep ^DEVICE ' . $mdadm_conf . '); do [[ "$bd" == "DEVICE" ]] && continue; ';
    $get_uuid_cmd .= 'blkid --output export "$bd" | sed -n -e s/[\-:]//g -e /^UUID=/s/^UUID=//p; done | sort -u';
    my $uuid = script_output $get_uuid_cmd;
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

    # Record pacemaker status
    systemctl 'status pacemaker', timeout => $default_timeout;

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
        wait_until_resources_started;
    }

    # And check for the state of the whole cluster
    check_cluster_state;

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
