# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use strict;
use testapi;
use lockapi;

sub run() {
    my $self         = shift;
    my $sbd_device   = "/dev/disk/by-path/ip-*-lun-0";
    my $cluster_init = script_output "ha-cluster-init -y -s $sbd_device; echo ha_cluster_init=\$?", 120;
    if ($cluster_init =~ /ha_cluster_init=1/) {    #failed to initialize the cluster, trying again
        upload_logs "/var/log/ha-cluster-bootstrap.log";
        type_string "ha-cluster-init -y -s /dev/disk/by-path/ip-*-lun-0; echo ha_cluster_init=\$? > /dev/$serialdev\n";
        die "ha-cluster-init failed" unless wait_serial "ha_cluster_init=0", 60;
    }
    upload_logs "/var/log/ha-cluster-bootstrap.log";
    type_string "crm_mon -1\n";
    save_screenshot;
    assert_script_run "crm resource stop stonith-sbd";
    assert_script_run "crm_mon -1";
    assert_script_run "sbd -d $sbd_device message " . get_var("HOSTNAME") . " exit";
    type_string "ps -A | grep sbd\n";
    assert_script_run "sbd -d $sbd_device -1 30 -4 60 create";
    assert_script_run "crm resource start stonith-sbd";
    assert_script_run "systemctl restart pacemaker";
    save_screenshot;
    for (1 .. 5) {
        $self->clear_and_verify_console;
        assert_script_run "crm_mon -1";
        if (check_screen("ha-crm-mon-" . get_var("CLUSTERNAME") . "-host1-online", 5)) {
            last;
        }
    }
    assert_screen("ha-crm-mon-" . get_var("CLUSTERNAME") . "-host1-online");
    $self->barrier_wait("CLUSTER_INITIALIZED");
    $self->barrier_wait("NODE2_JOINED");
    type_string "crm_mon -1\n";
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
