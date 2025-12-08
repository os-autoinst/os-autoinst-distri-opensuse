# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Create filesystem and check content
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'haclusterbasetest';
use utils qw(zypper_call write_sut_file);
use version_utils qw(is_sle);
use testapi;
use lockapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);

sub run {
    # Exit of this module if 'tag=drbd_passive' and if we are in a maintenance update not related to drbd
    my $tag = read_tag;
    return 1 if (($tag eq 'drbd_passive' and is_not_maintenance_update('drbd')) or $tag eq 'skip_fs_test');

    # On older SPs (<=15-SP3), this module has issues when setting up a filesystem HA resource
    # for drbd_passive using the serial terminal: it times out after the `crm resource move`
    # operation after 90 seconds; however, when running on the `root-console` it works. To avoid
    # adding an unnecessary sleep in all scenarios, the lines below move the module to run on the serial
    # terminal only when setting up a FS for drbd_passive. In other cases we select the root-console by
    # calling prepare_console_for_fencing
    ($tag eq 'drbd_passive') ? prepare_console_for_fencing : select_serial_terminal;

    my $cluster_name = get_cluster_name;
    my $node = get_hostname;
    my $fs_lun = undef;
    my $fs_rsc = undef;
    my $resource = 'lun';
    my $fs_type = get_var('HA_CLUSTER_MD_FS_TYPE', is_sle('16+') ? 'gfs2' : 'ocfs2');
    my %fs_opts = (
        xfs => '-f',
        ocfs2 => '-F -N 16',    # Force the filesystem creation and allows 16 nodes
        gfs2 => '-t hacluster:mygfs2 -p lock_dlm -j 16 -O'    # https://documentation.suse.com/it-it/sle-ha/15-SP6/html/SLE-HA-all/cha-ha-gfs2.html
    );

    # This Filesystem test can be called multiple time
    if ($tag eq 'cluster_md') {
        $resource = 'cluster_md';
    }
    elsif ($tag eq 'drbd_passive') {
        $resource = 'drbd_passive';

        # For sle16 MU, /dev/drbd_passive is not generated, /dev/drbd0 replace it.
        # So we need to add this workaround here.
        # See more detail in https://bugzilla.suse.com/show_bug.cgi?id=1247534#c23
        if (is_node(1)) {
            $fs_lun = '/dev/drbd_passive';
            $fs_lun = '/dev/drbd0' if (is_sle('>=16') && script_run('ls -la /dev/drbd_passive'));
        }
        $fs_type = 'xfs';
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

    # gfs2-utils is not installed by default, so we need to install it if needed
    # Not known currently if behaviour will be the same in 16. The below line assumes
    # gfs2 packages will come pre-installed in 16, so an explicit installation will not
    # be needed. If this is not the case, we drop the `&& is_sle('<16')` in a later commit
    zypper_call 'in gfs2-utils gfs2-kmp-default' if ($fs_type eq 'gfs2' && is_sle('<16'));
    # xfsprogs is not installed by default, so we need to install it if needed
    zypper_call 'in xfsprogs' if (!is_package_installed 'xfsprogs' and ($fs_type eq 'xfs'));

    # ocfs2 package should be installed by default. Also check for gfs2-kmp-default if needed
    if ($fs_type ne 'xfs') {
        die "$fs_type-kmp-default kernel package is not installed" unless is_package_installed "$fs_type-kmp-default";
    }

    # Format the Filesystem device
    if (is_node(1)) {
        assert_script_run "mkfs.$fs_type $fs_opts{$fs_type} \"$fs_lun\"", $default_timeout;
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
        # Only OCFS2 and GFS can be cloned
        if ($fs_type eq 'ocfs2' || $fs_type eq 'gfs2') {
            $edit_crm_config_script .= "
EDITOR='sed -ie \"s/^\\(group base-group.*\\)/\\1 $fs_rsc/\"' crm configure edit
";
        }
        else {
            if ($resource eq 'drbd_passive') {
                my $role = is_sle('>=15-SP4') ? "Promoted" : "Master";
                $edit_crm_config_script .= "
EDITOR='sed -ie \"\$ a colocation colocation_$fs_rsc inf: $fs_rsc ms_$resource:$role\"' crm configure edit
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
        wait_until_resources_started;
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
                    wait_for_idle_cluster;
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
