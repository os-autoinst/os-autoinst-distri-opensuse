# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: lvm2
# Summary: Create clustered LVM in HA tests
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use version_utils 'is_sle';
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $lvm_conf = '/etc/lvm/lvm.conf';
    my $lv_name = 'lv_openqa';
    my $vg_exclusive = 'false';
    my $activation_mode = 'activation_mode=shared';
    my $vg_type = '--clustered y';
    my $resource = 'lun';
    my $vg_luns = undef;

    # This test can be called multiple time
    my $tag = read_tag;
    if ($tag eq 'cluster_md') {
        $resource = 'cluster_md';
        $vg_luns = '/dev/md*' if is_node(1);

        # Use a named RAID in SLE15
        $vg_luns = "/dev/md/$resource" if (is_sle('15+') && is_node(1));
    }
    elsif ($tag eq 'drbd_passive') {
        $resource = 'drbd_passive';
        $vg_luns = "/dev/$resource" if is_node(1);
        $vg_exclusive = 'true';
        $vg_type = '--clustered n';
    }
    elsif ($tag eq 'drbd_active') {
        $resource = 'drbd_active';
        $vg_luns = "/dev/$resource" if is_node(1);
    }
    else {
        $vg_luns = '"' . get_lun . '" "' . get_lun . '"' if is_node(1);
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
        assert_script_run "lvcreate -n $lv_name -l100%FREE $vg_name";

        # With lvmlockd, VG lock should be stopped before starting HA resource
        if (get_var("USE_LVMLOCKD")) {
            # With slow HW "vgchange -an" might fail with RC5 at the first try
            my $start_time = time;
            while (script_run "vgchange -an $vg_name") {
                if (time - $start_time < $default_timeout) {
                    sleep 5;
                }
                else {
                    # if command fails, "-dddddd" redirects debug LV6 to /var/log/messages
                    script_run "vgchange -an -dddddd $vg_name";
                    die "Volume group was not deactivated within $default_timeout seconds.";
                }
            }
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
"EDITOR=\"sed -ie '\$ a primitive $vg_name ocf:heartbeat:LVM-activate params vgname=$vg_name vg_access_mode=lvmlockd $activation_mode'\" crm configure edit";
        }
        else {
            assert_script_run
              "EDITOR=\"sed -ie '\$ a primitive $vg_name ocf:heartbeat:LVM params volgrpname=$vg_name exclusive=$vg_exclusive'\" crm configure edit";
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
