# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize barriers used in HA cluster tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use lockapi;
use mmapi;

sub run() {
    my $self = shift;

    for my $clustername (split(/,/, get_var('CLUSTERNAME'))) {
        barrier_create("BARRIER_HA_" . $clustername,               3);
        barrier_create("CLUSTER_INITIALIZED_" . $clustername,      2);
        barrier_create("NODE2_JOINED_" . $clustername,             2);
        barrier_create("DLM_INIT_" . $clustername,                 2);
        barrier_create("DLM_GROUPS_CREATED_" . $clustername,       2);
        barrier_create("DLM_CHECKED_" . $clustername,              2);
        barrier_create("OCFS2_INIT_" . $clustername,               2);
        barrier_create("OCFS2_MKFS_DONE_" . $clustername,          2);
        barrier_create("OCFS2_GROUP_ALTERED_" . $clustername,      2);
        barrier_create("OCFS2_DATA_COPIED_" . $clustername,        2);
        barrier_create("OCFS2_MD5_CHECKED_" . $clustername,        2);
        barrier_create("BEFORE_FENCING_" . $clustername,           2);
        barrier_create("FENCING_DONE_" . $clustername,             2);
        barrier_create("LOGS_CHECKED_" . $clustername,             2);
        barrier_create("CLVM_INIT_" . $clustername,                2);
        barrier_create("CLVM_RESOURCE_CREATED_" . $clustername,    2);
        barrier_create("CLVM_PV_VG_LV_CREATED_" . $clustername,    2);
        barrier_create("CLVM_VG_RESOURCE_CREATED_" . $clustername, 2);
        barrier_create("CLVM_RW_CHECKED_" . $clustername,          2);
        barrier_create("CLVM_MD5SUM_" . $clustername,              2);
        #    barrier_create("PACEMAKER_CTS_INSTALLED_" . $clustername, 2);
        #    barrier_create("PACEMAKER_CTS_FINISHED_" . $clustername, 2);
    }
    wait_for_children_to_start;
    for my $clustername (split(/,/, get_var('CLUSTERNAME'))) {
        barrier_wait("BARRIER_HA_" . $clustername);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
