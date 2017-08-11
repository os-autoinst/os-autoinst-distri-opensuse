# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create clustered LVM in HA tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self       = shift;
    my $lvm_conf   = '/etc/lvm/lvm.conf';
    my $vg_name    = 'vg_openqa';
    my $lv_name    = 'lv_openqa';
    my $clvm_lun_1 = '/dev/disk/by-path/ip-*-lun-1';
    my $clvm_lun_2 = '/dev/disk/by-path/ip-*-lun-2';

    # Wait until cLVM test is initialized
    barrier_wait('CLVM_INIT_' . $self->cluster_name);

    # Test if cLVM packages are installed
    assert_script_run 'rpm -q lvm2-clvm lvm2-cmirrord';

    # Configure LVM for HA cluster
    assert_script_run "sed -ie '/^ *filter/d' $lvm_conf";                            # By default /dev/disk/by-path/ is filtered in lvm.conf
    assert_script_run "sed -ie 's/^\\( *use_lvmetad *=\\) *1/\\1 0/' $lvm_conf";     # Set use_lvmetad = 0, lvmetad doesn't support cLVM
    assert_script_run "sed -ie 's/^\\( *locking_type *=\\) *1/\\1 3/' $lvm_conf";    # Use locking_type=3 for cLVM

    # Add cLVM into the cluster configuration
    if ($self->is_node(1)) {
        if (get_var('SP2ORLATER')) {
            # SP2 recommends to use ocf:heartbeat:clvm RA
            assert_script_run 'EDITOR="sed -ie \'$ a primitive clvmd ocf:heartbeat:clvm op monitor interval=60 timeout=90\'" crm configure edit';
        }
        else {
            # Create clvmd primitive
            assert_script_run 'EDITOR="sed -ie \'$ a primitive clvmd ocf:lvm2:clvmd op monitor interval=60 timeout=60\'" crm configure edit';
        }
        # Add clvmd to base-group
        assert_script_run 'EDITOR="sed -ie \'s/^\\(group base-group.*\\)/\1 clvmd/\'" crm configure edit';

        # Wait to get clvmd running on all nodes
        sleep 10;
    }
    else {
        diag 'Wait until clvmd resource is created...';
    }

    # Wait until cLVM resource is created
    barrier_wait('CLVM_RESOURCE_CREATED_' . $self->cluster_name);

    # Do a check of the cluster with a screenshot
    $self->save_state;

    # cLVM process needs to be started
    assert_script_run 'ps -A | grep -q clvmd';
    if ($self->is_node(1)) {
        # Create PV-VG-LV
        assert_script_run "pvcreate --yes $clvm_lun_1 $clvm_lun_2";
        assert_script_run "vgcreate -cy $vg_name $clvm_lun_1 $clvm_lun_2";
        assert_script_run "lvcreate -n$lv_name -l100%FREE $vg_name";
    }
    else {
        diag 'Wait until PV-VG-LV is created...';
    }

    # Wait until PV-VG-LV is created
    barrier_wait('CLVM_PV_VG_LV_CREATED_' . $self->cluster_name);

    if ($self->is_node(1)) {
        # Create vg primitive
        assert_script_run
          "EDITOR=\"sed -ie '\$ a primitive vg ocf:heartbeat:LVM param volgrpname=$vg_name op monitor interval=60 timeout=60'\" crm configure edit";
        assert_script_run 'EDITOR="sed -ie \'s/^\\(group base-group.*\\)/\1 vg/\'" crm configure edit';

        # Wait to get VG active on all nodes
        sleep 10;
    }
    else {
        diag 'Wait until LVM resource is created...';
    }

    # Wait until LVM resource is created
    barrier_wait('CLVM_VG_RESOURCE_CREATED_' . $self->cluster_name);

    # VG/LV need to be here for the test to continu
    assert_script_run "ls -la /dev/$vg_name";

    # Something very simple, just to check, that LV has RW access to the same offset
    if ($self->is_node(1)) {
        assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=31";
        assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=30";
    }
    else {
        assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=30";
        assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=31";
    }

    # Wait until R/W state is checked
    barrier_wait('CLVM_RW_CHECKED_' . $self->cluster_name);

    # Wait until files integrity are checked
    assert_script_run "md5sum /dev/$vg_name/$lv_name";
    barrier_wait('CLVM_MD5SUM_' . $self->cluster_name);

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
