# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create OCFS2 filesystem and check content
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self      = shift;
    my $ocfs2_lun = '/dev/disk/by-path/ip-*-lun-3';

    # Wait until OCFS2 test is initialized
    barrier_wait('OCFS2_INIT_' . $self->cluster_name);

    # DLM process needs to be started
    assert_script_run 'ps -A | grep -q dlm_controld';

    # Format the OCFS2 device
    # Force the filesystem creation and allows 16 nodes
    if ($self->is_node(1)) {
        assert_script_run "mkfs.ocfs2 -F -N 16 $ocfs2_lun";
    }
    else {
        diag 'Wait until OCFS2 device is formatted...';
    }

    # Wait until OCFS2 device is formatted
    barrier_wait('OCFS2_MKFS_DONE_' . $self->cluster_name);

    if ($self->is_node(1)) {
        # Create the OCFS resource
        assert_script_run
"EDITOR=\"sed -ie '\$ a primitive ocfs2-1 ocf:heartbeat:Filesystem params device='\$(ls -1 $ocfs2_lun)' directory='/srv/ocfs2' fstype='ocfs2' options='acl' op monitor interval=20 timeout=40'\" crm configure edit";
        assert_script_run 'EDITOR="sed -ie \'s/group base-group dlm/group base-group dlm ocfs2-1/\'" crm configure edit';

        # Wait to get OCFS2 running on all nodes
        sleep 10;
    }
    else {
        diag 'Wait until OCFS2 resource is added...';
    }

    # Wait until OCFS2 resource is added
    barrier_wait('OCFS2_GROUP_ADDED_' . $self->cluster_name);

    if ($self->is_node(1)) {
        # Add files/data in the OCFS2 filesystem
        assert_script_run 'cp -r /usr/bin/ /srv/ocfs2';
        assert_script_run 'cd /srv/ocfs2; find bin/ -exec md5sum {} \; > out';
    }
    else {
        diag 'Wait until OCFS2 is filled with data...';
    }

    # Wait until OCFS2 is filled with data
    barrier_wait('OCFS2_DATA_COPIED_' . $self->cluster_name);

    if ($self->is_node(1)) {
        diag 'Wait until OCFS2 content is checked on other nodes...';
    }
    else {
        # Check if files/data are different in the OCFS2 filesystem
        assert_script_run 'cd /srv/ocfs2; find bin/ -exec md5sum {} \; > out_$(hostname)';
        assert_script_run 'diff out out_$(hostname)';
    }

    # Wait until OCFS2 content is checked
    barrier_wait('OCFS2_MD5_CHECKED_' . $self->cluster_name);

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
