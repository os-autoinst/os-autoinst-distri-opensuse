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
    if (is_node(1) && !get_var('HDDVERSION')) {
        reset_consoles;
        select_console 'root-console';
    }
    # This code is also called after boot on update tests. We must ensure to be on the root console
    # in that case
    select_console 'root-console' if (get_var('HDDVERSION'));

    # Workaround network timeout issue during upgrade
    if (get_var('HDDVERSION')) {
        assert_script_run 'journalctl -b --no-pager > bsc1129385-check-journal.log';
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
        assert_screen 'root-console',                    $default_timeout;
        assert_script_run 'systemctl restart pacemaker', $default_timeout;
    }
    assert_script_run 'systemctl list-units | grep iscsi', $default_timeout;
    assert_script_run 'systemctl status pacemaker',        $default_timeout;

    # Wait for resources to be started
    if (is_sles4sap) {
        wait_until_resources_started(timeout => 300);
    }
    else {
        wait_until_resources_started;
    }

    # And check for the state of the whole cluster
    check_cluster_state;

    # Synchronize all nodes
    barrier_wait("CHECK_AFTER_REBOOT_END_$cluster_name");

    barrier_wait("HAWK_FENCE_$cluster_name") if (check_var('HAWKGUI_TEST_ROLE', 'server'));
}

1;
