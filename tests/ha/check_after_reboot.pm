# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status *after* reboot
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use version_utils 'is_sles4sap';
use utils 'systemctl';

sub run {
    my $cluster_name = get_cluster_name;
    # In ppc64le and aarch64, workers are slower
    my $timeout_scale = get_var('TIMEOUT_SCALE', 2);
    $timeout_scale = 2 if ($timeout_scale < 2);
    set_var('TIMEOUT_SCALE', $timeout_scale) unless (check_var('ARCH', 'x86_64'));

    # Check cluster state *after* reboot
    barrier_wait("CHECK_AFTER_REBOOT_BEGIN_$cluster_name");

    # We need to be sure to be root and, after fencing, the default console on node01 is not root
    # Only do this on node01, as node02 console is expected to be the root-console
    if ((is_node(1) && !get_var('HDDVERSION')) || (is_node(2) && check_var('QDEVICE_TEST_ROLE', 'client'))) {
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
        my $pcmk_fails  = script_run 'egrep -q "pacemaker.service.+failed" bsc1129385-check-journal.log';

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
        assert_screen 'iscsi-client-target-connected', $default_timeout;
        send_key 'alt-c';
        wait_still_screen 3;
        wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";
        assert_screen 'root-console', $default_timeout;
        systemctl 'restart pacemaker', timeout => $default_timeout;
    }
    systemctl 'list-units | grep iscsi', timeout => $default_timeout;
    systemctl 'status pacemaker',        timeout => $default_timeout;

    # Wait for resources to be started
    if (is_sles4sap) {
        if (get_var('HA_CLUSTER_INIT') && check_var('CLUSTER_NAME', 'hana')) {
            my $instance_id = get_required_var('INSTANCE_ID');
            my $sid         = get_required_var('INSTANCE_SID');
            my $sapadm      = lc($sid) . "adm";
            my $node2       = choose_node(2);
            if (check_var('AUTOMATED_REGISTER', 'false')) {
                sleep bmwqemu::scale_timeout(300);
                assert_script_run "su - $sapadm -c 'hdbnsutil -sr_register --name=NODE1 --remoteHost=$node2 --remoteInstance=$instance_id --replicationMode=sync --operationMode=logreplay'";
                sleep 10;
                assert_script_run "crm resource cleanup rsc_SAPHana_${sid}_HDB$instance_id", 300;
            }
        }
        barrier_wait("HANA_RA_RESTART_$cluster_name") if check_var('CLUSTER_NAME', 'hana');
        wait_until_resources_started(timeout => 900);
    }
    else {
        wait_until_resources_started;
    }

    # And check for the state of the whole cluster
    check_cluster_state;

    # Synchronize all nodes
    barrier_wait("CHECK_AFTER_REBOOT_END_$cluster_name");

    barrier_wait("HAWK_FENCE_$cluster_name") if (check_var('HAWKGUI_TEST_ROLE', 'server'));

    barrier_wait("QNETD_TESTS_DONE_$cluster_name") if (check_var('QDEVICE_TEST_ROLE', 'client'));
}

1;
