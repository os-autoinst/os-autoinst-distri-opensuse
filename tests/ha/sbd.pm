# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sbd crmsh
# Summary: Add stonith sbd resource
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(systemctl);
use version_utils qw(is_sle);
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $sbd_cfg = '/etc/sysconfig/sbd';

    if (is_node(1)) {
        # Create sbd device
        my $sbd_lun = get_lun;
        assert_script_run "sbd -d \"$sbd_lun\" create";

        # Add sbd device in /etc/sysconfig/sbd
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/sbd.template -o $sbd_cfg";

        # And modify the template according to our needs
        assert_script_run "sed -i 's|%SBD_DEVICE%|$sbd_lun|g' $sbd_cfg";

        # Execute csync2 to synchronise the configuration files
        exec_csync;

        # Add stonith/sbd resource
        assert_script_run "crm configure primitive stonith-sbd stonith:external/sbd params pcmk_delay_max=30s";
        sleep 5;
        save_state;
    }

    barrier_wait("SBD_DONE_$cluster_name");

    # Enable SBD to start with Pacemaker
    systemctl 'enable sbd';
    sleep 5;

    # We need to restart the cluster to start SBD
    # A mutex is used to restart one node at a time
    mutex_lock 'cluster_restart';
    if (is_sle('12-SP4+')) {
        assert_script_run "crm cluster restart";
    }
    else {
        assert_script_run "crm cluster stop";
        assert_script_run "crm cluster start";
    }
    mutex_unlock 'cluster_restart';

    # Print SBD information
    assert_script_run "cat $sbd_cfg";

    assert_script_run ". /etc/sysconfig/sbd";
    assert_script_run "sbd -d \$SBD_DEVICE dump";
    assert_script_run "sbd -d \$SBD_DEVICE list";
    save_screenshot;
}

1;
