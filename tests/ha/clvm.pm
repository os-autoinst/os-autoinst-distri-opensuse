# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create clustered LVM in HA tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self             = shift;
    my $vg_name          = "vg_openqa";
    my $lv_name          = "lv_openqa";
    my $clvm_partition_1 = "/dev/disk/by-path/ip-*-lun-4";
    my $clvm_partition_2 = "/dev/disk/by-path/ip-*-lun-5";

    barrier_wait("CLVM_INIT_" . $self->cluster_name);
    # assert_script_run "zypper -n install dlm-kmp-default lvm2-clvm lvm2-cmirrord";
    assert_script_run
      q(sed -ie '/^ *filter/d' /etc/lvm/lvm.conf);    #by default /dev/disk/by-path/ is filtered in lvm.conf
    assert_script_run q(sed -ie 's/^\\( *use_lvmetad *=\\) *1/\1 0/' /etc/lvm/lvm.conf)
      ;                                               #set use_lvmetad = 0, lvmetad doesn't support cLVM
    assert_script_run q(sed -ie 's/^\\( *locking_type *=\\) *1/\1 3/' /etc/lvm/lvm.conf);   #use locking_type=3 for cLVM
    if ($self->is_node1) {
        type_string "echo wait until clvmd resource is created\n";
    }
    else {
        if (get_var("SP2ORLATER")) {
            # sp2 recommends to use ocf:heartbeat:clvm RA
            assert_script_run
q(EDITOR="sed -ie '$ a primitive clvmd ocf:heartbeat:clvm op monitor interval=60 timeout=60'" crm configure edit);
        }
        else {
            # create clvmd primitive
            assert_script_run
q(EDITOR="sed -ie '$ a primitive clvmd ocf:lvm2:clvmd op monitor interval=60 timeout=60'" crm configure edit);
        }
        # add clvmd to base-group
        assert_script_run q(EDITOR="sed -ie 's/^\\(group base-group.*\\)/\1 clvmd/'" crm configure edit);
        # wait to get clvmd running on all nodes
        sleep 10;
    }
    barrier_wait("CLVM_RESOURCE_CREATED_" . $self->cluster_name);

    type_string "ps -A | grep -q clvmd; echo clvmd_running=\$? > /dev/$serialdev\n";
    die "clvm daemon is not running" unless wait_serial "clvmd_running=0", 60;
    if ($self->is_node1) {
        type_string "echo wait until PV-VG-LV is created\n";
    }
    else {
        assert_script_run "pvcreate --yes $clvm_partition_1";
        assert_script_run "pvcreate --yes $clvm_partition_2";
        assert_script_run "vgcreate -cy $vg_name $clvm_partition_1 $clvm_partition_2";
        assert_script_run "lvcreate -n$lv_name -L100M $vg_name";
    }
    barrier_wait("CLVM_PV_VG_LV_CREATED_" . $self->cluster_name);

    if ($self->is_node1) {
        type_string "echo wait until LVM resource is created\n";
    }
    else {
        assert_script_run
qq(EDITOR="sed -ie '\$ a primitive vg ocf:heartbeat:LVM param volgrpname=$vg_name op monitor interval=60 timeout=60'" crm configure edit)
          ;    #create vg primitive
        assert_script_run q(EDITOR="sed -ie 's/^\\(group base-group.*\\)/\1 vg/'" crm configure edit);
        sleep 10;    #wait to get VG active on all nodes
    }
    barrier_wait("CLVM_VG_RESOURCE_CREATED_" . $self->cluster_name);

    assert_script_run "ls -la /dev/$vg_name 2>&1";
    #dd if=/dev/urandom of=/dev/vg_openqa/lv_openqa bs=5M count=1 skip=30
    #dd if=/dev/vg_openqa/lv_openqa of=testfile bs=5M count=1 seek=30
    if ($self->is_node1) {    #something very simple, just to check, that LV has RW access to the same offset
        assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=30";
        assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=31";
    }
    else {
        assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=31";
        assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=30";
    }
    barrier_wait("CLVM_RW_CHECKED_" . $self->cluster_name);
    assert_script_run "md5sum /dev/$vg_name/$lv_name";
    barrier_wait("CLVM_MD5SUM_" . $self->cluster_name);
}

1;
