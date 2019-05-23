# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add stonith sbd resource
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils 'systemctl';
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $sbd_cfg      = '/etc/sysconfig/sbd';

    if (is_node(1)) {
        # Create sbd device
        my $sbd_lun = get_lun;
        assert_script_run "sbd -d $sbd_lun create";

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
    assert_script_run "crm cluster restart";
    mutex_unlock 'cluster_restart';

    # Print SBD information
    assert_script_run "cat $sbd_cfg";

    assert_script_run ". /etc/sysconfig/sbd";
    assert_script_run "sbd -d \$SBD_DEVICE dump";
    assert_script_run "sbd -d \$SBD_DEVICE list";
    save_screenshot;
}

1;
