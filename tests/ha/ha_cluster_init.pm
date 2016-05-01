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
    #    assert_script_run "sbd -d $sbd_device -1 30 create"; #create SBD with 30s watchdog timeout
    #    assert_script_run "sbd -d $sbd_device dump";
    #    save_screenshot;
    upload_logs "/var/log/ha-cluster-bootstrap.log";
    type_string "crm_mon -1\n";
    save_screenshot;
    $self->barrier_wait("CLUSTER_INITIALIZED");
    $self->barrier_wait("NODE2_JOINED");
    type_string "crm_mon -1\n";
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
