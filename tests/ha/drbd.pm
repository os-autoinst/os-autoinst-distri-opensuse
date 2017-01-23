# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: DRBD OpenQA test
# Add two new VARIABLES DRBD_LUN0 and DRBD_LUN1
# Create DRBD Device
# Create crm ressource
# Check resource migration
# Check multistate status
# Maintainer: Haris Sehic <hsehic@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self    = shift;
    my $lun0    = get_var("DRBD_LUN0");
    my $lun1    = get_var("DRBD_LUN1");
    my $host1ip = script_output("host -t A host1 | cut -d' ' -f4");
    my $host2ip = script_output("host -t A host2 | cut -d' ' -f4");

    barrier_wait("DRBD_INIT_" . $self->cluster_name);
    assert_script_run
q(awk -e '{print;}/startup {/{print "wfc-timeout 100;\ndegr-wfc-timeout 120;"};' /etc/drbd.d/global_common.conf >/tmp/global_common.conf && mv /tmp/global_common.conf /etc/drbd.d/global_common.conf);
    assert_script_run "curl -f -v " . autoinst_url . "/data/ha/drbd9.r0.res.template -o /etc/drbd.d/r0.res";
    assert_script_run q(sed -i 's/ADDR1/) . $host1ip . q(/' /etc/drbd.d/r0.res);
    assert_script_run q(sed -i 's/ADDR2/) . $host2ip . q(/' /etc/drbd.d/r0.res);
    save_screenshot;
    assert_script_run "drbdadm create-md r0";
    assert_script_run "drbdadm up r0";
    barrier_wait("DRBD_CREATE_DEVICE_HOST1_" . $self->cluster_name);
    if ($self->is_node1) {
        assert_script_run "drbdadm primary --force r0";
        assert_script_run "drbdadm status r0";
        # run assert_script_run timeout 240 during the long assert_script_run drbd sync
        assert_script_run
          q(while ! `drbdadm status r0 | grep -q "peer-disk:UpToDate"`; do sleep 10; drbdadm status r0;  done), 240;
    }
    else {
        type_string "echo wait until drbd device is created\n";
    }
    save_screenshot;
    barrier_wait("DRBD_CHECK_DEVICE_HOST2_" . $self->cluster_name);
    if ($self->is_node1) {
        type_string "echo wait until drbd status is set\n";
    }
    else {
        assert_script_run "drbdadm status r0";
        # run assert_script_run timeout 240 during the long assert_script_run drbd sync
        assert_script_run
          q(while ! `drbdadm status r0 | grep -q "peer-disk:UpToDate"`; do sleep 10;drbdadm status r0; done), 240;
    }
    save_screenshot;
    barrier_wait("DRBD_SETUP_DONE_" . $self->cluster_name);
    if ($self->is_node1) {
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/drbd9.crm.config -o /tmp/r0.crm";
        assert_script_run "crm configure load update /tmp/r0.crm";
        # check for result
        assert_script_run "crm resource status ms-drbd-data | grep 'host1 Master'";
    }
    save_screenshot;
    barrier_wait("DRBD_CHECKED_" . $self->cluster_name);
    if ($self->is_node1) {
        #do nothing
    }
    else {
        assert_script_run "crm resource migrate ms-drbd-data host2";
        # check the migration / timeout 240 sec it takes some time to update
        assert_script_run
          q(while ! `drbdadm status r0 | grep -q "r0 role:Primary"`; do sleep 10; drbdadm status r0;  done), 240;
        assert_script_run "crm resource status ms-drbd-data | grep 'host2 Master'";
    }
    barrier_wait("DRBD_MIGRATIONDONE_" . $self->cluster_name);
}

1;
