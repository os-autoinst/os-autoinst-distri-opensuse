# SUSE's openQA tests
#
# Copyright (c) 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create clustered LVM in HA tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    my $lvm_conf     = '/etc/lvm/lvm.conf';
    my $lv_name      = 'lv_openqa';
    my $vg_exclusive = 'false';
    my $resource     = 'clvm';
    my $clvm_luns    = undef;
    my $clustered_vg = 'y';

    # This cLVM test can be called multiple time
    if (read_tag eq 'cluster_md') {
        $resource  = 'cluster_md';
        $clvm_luns = '/dev/md*';
        #$clvm_luns = "/dev/md/$resource";
    }
    elsif (read_tag eq 'drbd_passive') {
        $resource     = 'drbd_passive';
        $clvm_luns    = "/dev/$resource";
        $vg_exclusive = 'true';
        $clustered_vg = 'n';
    }
    elsif (read_tag eq 'drbd_active') {
        $resource  = 'drbd_active';
        $clvm_luns = "/dev/$resource";
    }
    else {
        $clvm_luns = block_device_real_path '/dev/disk/by-path/ip-*-lun-1' . ' ' . block_device_real_path '/dev/disk/by-path/ip-*-lun-2';
    }
    my $vg_name = "vg_$resource";

    # Create tag for barrier_wait
    my $barrier_tag = uc $resource;

    # At this time, we only test DRBD on a 2 nodes cluster
    # And if the cluster has more than 2 nodes, we only use the first 2 nodes
    if ($resource =~ /^drbd_/) {
        return if (!is_node(1) && !is_node(2));
    }

    # Check if the resource is running
    die "$resource is not running" unless check_rsc "$resource";

    # Wait until cLVM test is initialized
    barrier_wait("CLVM_INIT_${barrier_tag}_$cluster_name");

    # Test if cLVM packages are installed
    assert_script_run 'rpm -q lvm2-clvm lvm2-cmirrord';

    # Configure LVM for HA cluster (if it has not already been done)
    if (!script_run 'systemctl status lvm2-lvmetad.socket') {
        lvm_add_filter('r', '/dev/.\*/by-partuuid/.\*');
        assert_script_run "sed -ie 's/^\\( *use_lvmetad *=\\) *1/\\1 0/' $lvm_conf";     # Set use_lvmetad = 0, lvmetad doesn't support cLVM
        assert_script_run "sed -ie 's/^\\( *locking_type *=\\) *1/\\1 3/' $lvm_conf";    # Use locking_type=3 for cLVM
        assert_script_run 'systemctl stop lvm2-lvmetad.socket';                          # Stop lvmetad
        assert_script_run 'systemctl disable lvm2-lvmetad.socket';                       # Disable lvmetad
    }

    # Add cLVM into the cluster configuration
    if (is_node(1)) {
        # Add clvmd to base-group if it's not already done
        if (script_run 'crm resource status clvm') {
            assert_script_run 'EDITOR="sed -ie \'$ a primitive clvm ocf:heartbeat:clvm param activate_vgs=false\'" crm configure edit';
            assert_script_run 'EDITOR="sed -ie \'s/^\\(group base-group.*\\)/\1 clvm/\'" crm configure edit';

            # Wait to get clvmd running on all nodes
            sleep 5;
        }
    }
    else {
        diag 'Wait until clvmd resource is created...';
    }

    # Wait until cLVM resource is created
    barrier_wait("CLVM_RESOURCE_CREATED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    # DLM process needs to be started
    ensure_process_running 'dlm_controld';

    if (is_node(1)) {
        # Create PV-VG-LV
        assert_script_run "pvcreate -y $clvm_luns";
        assert_script_run "vgcreate -c$clustered_vg $vg_name $clvm_luns";
        assert_script_run "lvcreate -n $lv_name -l100%FREE $vg_name";
    }
    else {
        diag 'Wait until PV-VG-LV is created...';
    }

    # DRBD passive test need some specific LVM configuration *after* PV/VG/LV creation
    if ($resource eq 'drbd_passive') {
        my $vol_list = script_output "for I in \$(vgs -o vg_name --noheadings | grep -v $vg_name); do echo -e '\"\$I\", \\c'; done | sed 's/, \$//'";
        assert_script_run "sed -ie '/\\<volume_list\\>[[:blank:]][[:blank:]]*=/ a volume_list = [ $vol_list ]' $lvm_conf";
    }


    # Wait until PV-VG-LV is created
    barrier_wait("CLVM_PV_VG_LV_CREATED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    if (is_node(1)) {
        # Create vg primitive
        assert_script_run "EDITOR=\"sed -ie '\$ a primitive $vg_name ocf:heartbeat:LVM param volgrpname=$vg_name exclusive=$vg_exclusive'\" crm configure edit";

        if ($resource eq 'drbd_passive') {
            # DRBD passive test need some specific HA configuration
            assert_script_run "EDITOR=\"sed -ie '\$ a colocation colocation_$vg_name inf: $vg_name ms_$resource:Master'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a order order_$vg_name inf: ms_$resource:promote $vg_name:start'\" crm configure edit";
        }
        else {
            assert_script_run "EDITOR=\"sed -ie 's/^\\(group base-group.*\\)/\\1 $vg_name/'\" crm configure edit";
        }

        # Wait to get VG active on all nodes
        sleep 5;
    }
    else {
        diag 'Wait until LVM resource is created...';
    }

    # Wait until LVM resource is created
    barrier_wait("CLVM_VG_RESOURCE_CREATED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    # VG/LV need to be here for the test to continu
    if ($resource ne 'drbd_passive') {
        assert_script_run "ls -la /dev/$vg_name";
    }

    # Something very simple, just to check, that LV has RW access to the same offset
    if (is_node(1)) {
        assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=31";
        assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=30";
    }
    else {
        # We can't do this test in active/passive mode
        if ($resource ne 'drbd_passive') {
            assert_script_run "dd if=/dev/urandom of=/dev/$vg_name/$lv_name bs=5M count=1 skip=30";
            assert_script_run "dd if=/dev/$vg_name/$lv_name of=test_file bs=5M count=1 seek=31";
        }
    }

    # Wait until R/W state is checked
    barrier_wait("CLVM_RW_CHECKED_${barrier_tag}_$cluster_name");

    # Wait until files integrity are checked
    if ($resource ne 'drbd_passive') {
        assert_script_run "md5sum /dev/$vg_name/$lv_name";
    }
    barrier_wait("CLVM_MD5SUM_${barrier_tag}_$cluster_name");
}

1;
# vim: set sw=4 et:
