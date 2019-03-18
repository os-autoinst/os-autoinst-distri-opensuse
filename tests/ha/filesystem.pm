# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create filesystem and check content
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use utils 'zypper_call';
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $node         = get_hostname;
    my $fs_lun       = undef;
    my $fs_rsc       = undef;
    my $resource     = 'lun';
    my $fs_type      = 'ocfs2';
    my $fs_opts      = '-F -N 16';         # Force the filesystem creation and allows 16 nodes

    # This Filesystem test can be called multiple time
    if (read_tag eq 'cluster_md') {
        $resource = 'cluster_md';
    }
    elsif (read_tag eq 'drbd_passive') {
        $resource = 'drbd_passive';
        $fs_lun   = '/dev/drbd_passive' if is_node(1);
        $fs_type  = 'xfs';
        $fs_opts  = '-f';
    }
    elsif (read_tag eq 'drbd_active') {
        $resource = 'drbd_active';
    }
    else {
        $fs_lun = get_lun if is_node(1);
    }
    $fs_lun = "/dev/vg_$resource/lv_openqa" if (not defined $fs_lun && is_node(1));
    $fs_rsc = "fs_$resource";

    # Create tag for barrier_wait
    my $barrier_tag = uc $resource;

    # At this time, we only test DRBD on a 2 nodes cluster
    # And if the cluster has more than 2 nodes, we only use the first 2 nodes
    if ($resource =~ /^drbd_/) {
        return if (!is_node(1) && !is_node(2));
    }

    # Check if the resource is running
    die "$resource is not running" unless check_rsc "$resource";

    # Wait until Filesystem test is initialized
    barrier_wait("FS_INIT_${barrier_tag}_$cluster_name");

    # DLM process needs to be started
    ensure_process_running 'dlm_controld';

    # ocfs2 package should be installed by default
    if ($fs_type eq 'ocfs2') {
        die 'ocfs2-kmp-default kernel package is not installed' unless is_package_installed 'ocfs2-kmp-default';
    }

    # xfsprogs is not installed by default, so we need to install it if needed
    zypper_call 'in xfsprogs' if (!is_package_installed 'xfsprogs' and ($fs_type eq 'xfs'));

    # Format the Filesystem device
    if (is_node(1)) {
        assert_script_run "mkfs -t $fs_type $fs_opts $fs_lun";
    }
    else {
        diag 'Wait until Filesystem device is formatted...';
    }

    # Wait until Filesystem device is formatted
    barrier_wait("FS_MKFS_DONE_${barrier_tag}_$cluster_name");

    if (is_node(1)) {
        # Create the Filesystem resource
        assert_script_run
"EDITOR=\"sed -ie '\$ a primitive $fs_rsc ocf:heartbeat:Filesystem params device='$fs_lun' directory='/srv/$fs_rsc' fstype='$fs_type''\" crm configure edit";

        # Only OCFS2 can be cloned
        if ($fs_type eq 'ocfs2') {
            assert_script_run "EDITOR=\"sed -ie 's/^\\(group base-group.*\\)/\\1 $fs_rsc/'\" crm configure edit";
        }
        else {
            if ($resource eq 'drbd_passive') {
                assert_script_run "EDITOR=\"sed -ie '\$ a colocation colocation_$fs_rsc inf: $fs_rsc ms_$resource:Master'\" crm configure edit";
                assert_script_run "EDITOR=\"sed -ie '\$ a order order_$fs_rsc Mandatory: ms_$resource:promote $fs_rsc:start'\" crm configure edit";
            }
            else {
                assert_script_run "EDITOR=\"sed -ie '\$ a colocation colocation_$fs_rsc inf: $fs_rsc vg_$resource'\" crm configure edit";
                assert_script_run "EDITOR=\"sed -ie '\$ a order order_$fs_rsc Mandatory: vg_$resource $fs_rsc'\" crm configure edit";
            }

            # Sometimes we need to cleanup the resource
            rsc_cleanup $fs_rsc;
        }

        # Wait to get Filesystem running on all nodes (if applicable)
        sleep 5;
    }
    else {
        diag 'Wait until Filesystem resource is added...';
    }

    # Wait until Filesystem resource is added
    barrier_wait("FS_GROUP_ADDED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    script_run 'df -h';
    save_state;

    if ($resource eq 'drbd_passive') {
        # To ensure a proper resource migration, we need to stop/start it
        if (is_node(1)) {
            assert_script_run "crm resource stop $fs_rsc";
        }

        # Wait for Filesystem to be stopped
        barrier_wait("FS_RESOURCE_STOPPED_${barrier_tag}_$cluster_name");
    }

    if (is_node(1)) {
        if ($resource eq 'drbd_passive') {
            # Start the resource
            script_run "crm resource start $fs_rsc";
            ensure_resource_running("$fs_rsc", "is running on:[[:blank:]]*$node\[[:blank:]]*\$");
        }

        # Add files/data in the Filesystem
        assert_script_run "cp -r /usr/bin/ /srv/$fs_rsc ; sync";
        assert_script_run "cd /srv/$fs_rsc/bin ; find . -type f -exec md5sum {} \\; > ../out";
    }
    else {
        diag 'Wait until Filesystem is filled with data...';
    }

    # Wait until Filesystem is filled with data
    barrier_wait("FS_DATA_COPIED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;

    if (is_node(1)) {
        diag 'Wait until Filesystem content is checked on other nodes...';
    }
    else {
        if ($resource eq 'drbd_passive') {
            if (is_node(2)) {
                # Arbitrary choice, a cluster always has at least two nodes
                $node = choose_node(2);

                # Migrate resource on the node
                assert_script_run "crm resource migrate ms_$resource $node";
                ensure_resource_running("$fs_rsc", "is running on:[[:blank:]]*$node\[[:blank:]]*\$");

                # Do a check of the cluster with a screenshot
                script_run 'df -h';
                save_state;
            }
            else {
                diag 'Wait until Filesystem content is checked on other nodes...';
            }
        }

        # Check if files/data are different in the Filesystem
        assert_script_run "cd /srv/$fs_rsc/bin ; find . -type f -exec md5sum {} \\; > ../out_$node";
        assert_script_run "cd /srv/$fs_rsc ; diff -urN out out_$node";
    }

    # Return to default directory
    type_string "cd\n";

    # Wait until Filesystem content is checked
    barrier_wait("FS_CHECKED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
