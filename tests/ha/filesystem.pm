# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Create filesystem and check content
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use utils 'zypper_call', 'write_sut_file';
use testapi;
use lockapi;
use hacluster;

sub run {
    # Exit of this module if 'tag=drbd_passive' and if we are in a maintenance update not related to drbd
    my $tag = read_tag;
    return 1 if (($tag eq 'drbd_passive' and is_not_maintenance_update('drbd')) or $tag eq 'skip_fs_test');

    my $cluster_name = get_cluster_name;
    my $node = get_hostname;
    my $fs_lun = undef;
    my $fs_rsc = undef;
    my $resource = 'lun';
    my $fs_type = 'ocfs2';
    my $fs_opts = '-F -N 16';    # Force the filesystem creation and allows 16 nodes

    # This Filesystem test can be called multiple time
    if ($tag eq 'cluster_md') {
        $resource = 'cluster_md';
    }
    elsif ($tag eq 'drbd_passive') {
        $resource = 'drbd_passive';
        $fs_lun = '/dev/drbd_passive' if is_node(1);
        $fs_type = 'xfs';
        $fs_opts = '-f';
    }
    elsif ($tag eq 'drbd_active') {
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
        assert_script_run "mkfs -t $fs_type $fs_opts \"$fs_lun\"", $default_timeout;
    }
    else {
        diag 'Wait until Filesystem device is formatted...';
    }

    # Wait until Filesystem device is formatted
    barrier_wait("FS_MKFS_DONE_${barrier_tag}_$cluster_name");

    if (is_node(1)) {
        # Create the Filesystem resource
        my $clean_flag = undef;
        my $edit_crm_config_script = "#!/bin/sh
EDITOR='sed -ie \"\$ a primitive $fs_rsc ocf:heartbeat:Filesystem params device=\'$fs_lun\' directory=\'/srv/$fs_rsc\' fstype=\'$fs_type\'\"' crm configure edit
";
        # Only OCFS2 can be cloned
        if ($fs_type eq 'ocfs2') {
            $edit_crm_config_script .= "
EDITOR='sed -ie \"s/^\\(group base-group.*\\)/\\1 $fs_rsc/\"' crm configure edit
";
        }
        else {
            if ($resource eq 'drbd_passive') {
                $edit_crm_config_script .= "
EDITOR='sed -ie \"\$ a colocation colocation_$fs_rsc inf: $fs_rsc ms_$resource:Master\"' crm configure edit
EDITOR='sed -ie \"\$ a order order_$fs_rsc Mandatory: ms_$resource:promote $fs_rsc:start\"' crm configure edit
";
            }
            else {
                $edit_crm_config_script .= "
EDITOR='sed -ie \"\$ a colocation colocation_$fs_rsc inf: $fs_rsc vg_$resource\"' crm configure edit
EDITOR='sed -ie \"\$ a order order_$fs_rsc Mandatory: vg_$resource $fs_rsc\"\' crm configure edit
";
            }
            $clean_flag = "cleanup";
        }

        # run bash script to edit crm configure
        write_sut_file '/root/crm_edit_config.sh', $edit_crm_config_script;
        assert_script_run 'bash -ex /root/crm_edit_config.sh', $default_timeout;

        # Sometimes we need to cleanup the resource
        rsc_cleanup $fs_rsc if defined($clean_flag) && $clean_flag == 'cleanup';

        # Wait to get Filesystem running on all nodes (if applicable)
        sleep 5;
    }
    else {
        diag 'Wait until Filesystem resource is added...';
    }

    # Wait until Filesystem resource is added
    barrier_wait("FS_GROUP_ADDED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    script_run 'df -h', $default_timeout;
    save_state;

    if ($resource eq 'drbd_passive') {
        # To ensure a proper resource migration, we need to stop/start it
        if (is_node(1)) {
            assert_script_run "crm resource stop $fs_rsc", $default_timeout;
        }

        # Wait for Filesystem to be stopped
        barrier_wait("FS_RESOURCE_STOPPED_${barrier_tag}_$cluster_name");
    }

    if (is_node(1)) {
        if ($resource eq 'drbd_passive') {
            # Start the resource
            script_run "crm resource start $fs_rsc", $default_timeout;
            ensure_resource_running("$fs_rsc", "is running on:[[:blank:]]*$node\[[:blank:]]*\$");
        }

        # Add files/data in the Filesystem
        assert_script_run "cp -r /usr/bin/ /srv/$fs_rsc ; sync", $default_timeout;
        assert_script_run "cd /srv/$fs_rsc/bin ; find . -type f -exec md5sum {} \\; > ../out", $default_timeout;
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

                # Workaround needed before 12sp4
                # Restart of master/slave rsc after fs_rsc configuration
                foreach my $action ('stop', 'start') {
                    assert_script_run "crm resource $action ms_$resource", $default_timeout;
                    sleep 5;
                }

                # Migrate resource on the node
                assert_script_run "crm resource move ms_$resource $node", $default_timeout;
                wait_for_idle_cluster;
                ensure_resource_running("$fs_rsc", "is running on:[[:blank:]]*$node\[[:blank:]]*\$");

                # Do a check of the cluster with a screenshot
                script_run 'df -h', $default_timeout;
                save_state;
            }
            else {
                diag 'Wait until Filesystem content is checked on other nodes...';
            }
        }

        # Check if files/data are different in the Filesystem
        assert_script_run "cd /srv/$fs_rsc/bin ; find . -type f -exec md5sum {} \\; > ../out_$node", $default_timeout;
        assert_script_run "cd /srv/$fs_rsc ; diff -urN out out_$node", $default_timeout;
    }

    # Return to default directory
    enter_cmd "cd";

    # Wait until Filesystem content is checked
    barrier_wait("FS_CHECKED_${barrier_tag}_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
