# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create HA cluster using ha-cluster-init
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use lockapi;

sub run {
    # Validate cluster creation with ha-cluster-init tool
    my $self          = shift;
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $sbd_device    = '/dev/disk/by-path/ip-*-lun-0';
    my $cluster_init  = script_output "ha-cluster-init -y -s $sbd_device; echo ha_cluster_init=\$?", 120;

    # Failed to initialize the cluster, trying again
    if ($cluster_init =~ /ha_cluster_init=1/) {
        upload_logs $bootstrap_log;
        assert_script_run "ha-cluster-init -y -s $sbd_device";
    }
    upload_logs $bootstrap_log;

    # Do a check of the cluster with a screenshot
    $self->save_state;

    # Validate SBD creation with sbd cli interface
    assert_script_run 'crm resource stop stonith-sbd';
    assert_script_run 'crm_mon -R -1';
    assert_script_run "sbd -d $sbd_device message " . get_var('HOSTNAME') . " exit";
    type_string "ps -A | grep sbd\n";
    # SBD default timeouts must be changed!
    assert_script_run "sbd -d $sbd_device -1 30 -4 60 create";
    assert_script_run 'crm resource start stonith-sbd';
    assert_script_run 'systemctl restart pacemaker';
    for (1 .. 5) {
        $self->clear_and_verify_console;
        assert_script_run 'crm_mon -R -1';
        if (check_screen('ha-crm-mon-sbd-started', 5)) {
            last;
        }
    }
    assert_screen('ha-crm-mon-sbd-started');
    barrier_wait('CLUSTER_INITIALIZED_' . $self->cluster_name);
    barrier_wait('NODE_JOINED_' . $self->cluster_name);

    # Do a check of the cluster with a screenshot
    $self->save_state;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
