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
use version_utils qw(is_sle sle_version_at_least);
use testapi;
use lockapi;
use hacluster;

sub run {
    my $lvm_conf        = '/etc/lvm/lvm.conf';
    my $lv_name         = 'lv_openqa';
    my $vg_exclusive    = 'false';
    my $activation_mode = 'activation_mode=shared';
    my $vg_type         = '--clustered y';
    my $resource        = 'lun';
    my $vg_luns         = undef;

    # This test can be called multiple time
    if (read_tag eq 'cluster_md') {
        $resource = 'cluster_md';
        $vg_luns  = '/dev/md*';

        # Use a named RAID in SLE15
        $vg_luns = "/dev/md/$resource" if (is_sle && sle_version_at_least('15'));
    }
    elsif (read_tag eq 'drbd_passive') {
        $resource     = 'drbd_passive';
        $vg_luns      = "/dev/$resource";
        $vg_exclusive = 'true';
        $vg_type      = '--clustered n';
    }
    elsif (read_tag eq 'drbd_active') {
        $resource = 'drbd_active';
        $vg_luns  = "/dev/$resource";
    }
    else {
        $vg_luns = block_device_real_path '/dev/disk/by-path/ip-*-lun-1' . ' ' . block_device_real_path '/dev/disk/by-path/ip-*-lun-2';
    }
    my $vg_name = "vg_$resource";

    # Create tag for barrier_wait
    my $barrier_tag = uc $resource;

    # At this time, we only test DRBD on a 2 nodes cluster
    # And if the cluster has more than 2 nodes, we only use the first 2 nodes
    if ($resource =~ /^drbd_/) {
        return if (!is_node(1) && !is_node(2));
    }

    # Wait until test is initialized
    barrier_wait("VG_INIT_${barrier_tag}_$cluster_name");

    # Check if the needed resource is running
    die "$resource is not running" unless check_rsc "$resource";

    if (is_node(1)) {
        # Create PV-VG-LV
        assert_script_run "pvcreate -y $vg_luns";
        $vg_type = '--shared' if (get_var("USE_LVMLOCKD"));
        assert_script_run "vgcreate $vg_type $vg_name $vg_luns";

        if (script_run "lvcreate -n $lv_name -l100%FREE $vg_name") {
            if (!get_var("USE_LVMLOCKD")) {
                # Sometimes an 'Error locking on node' error could appear
                # A refresh of clvmd is needed in this case, it's a old bug!
                record_soft_failure 'bsc#1076042';
                script_run 'clvmd -R ; sleep 5 ; clvmd -R';    # Multiple refresh could be necessary
                assert_script_run "lvcreate -n $lv_name -l100%FREE $vg_name";
            }
            else {
                die 'error while executing lvcreate command';
            }
        }

        # With lvmlockd, VG lock should be stopped before starting HA resource
        if (get_var("USE_LVMLOCKD")) {
            assert_script_run "vgchange -an $vg_name";
            assert_script_run "vgchange --lockstop $vg_name";
        }
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
    barrier_wait("PV_VG_LV_CREATED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    if (is_node(1)) {
        # Create vg primitive
        if (get_var("USE_LVMLOCKD")) {
            $activation_mode = undef if ($vg_exclusive eq 'true');
            assert_script_run
"EDITOR=\"sed -ie '\$ a primitive $vg_name ocf:heartbeat:LVM-activate param vgname=$vg_name vg_access_mode=lvmlockd $activation_mode'\" crm configure edit";
        }
        else {
            assert_script_run
              "EDITOR=\"sed -ie '\$ a primitive $vg_name ocf:heartbeat:LVM param volgrpname=$vg_name exclusive=$vg_exclusive'\" crm configure edit";
        }

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
    barrier_wait("VG_RESOURCE_CREATED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    # VG/LV need to be here for the test to continu
    assert_script_run "ls -la /dev/$vg_name" if ($resource ne 'drbd_passive');

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
    barrier_wait("VG_RW_CHECKED_${barrier_tag}_$cluster_name");

    # Wait until files integrity are checked
    assert_script_run "md5sum /dev/$vg_name/$lv_name" if ($resource ne 'drbd_passive');
    barrier_wait("VG_MD5SUM_${barrier_tag}_$cluster_name");
}

1;
# vim: set sw=4 et:
