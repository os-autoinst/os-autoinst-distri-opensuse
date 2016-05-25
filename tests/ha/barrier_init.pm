# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use strict;
use testapi;
use lockapi;

sub run() {
    my $self = shift;

    $self->barrier_create("CLUSTER_INITIALIZED");
    $self->barrier_create("NODE2_JOINED");
    $self->barrier_create("OCFS2_INIT");
    $self->barrier_create("DLM_GROUPS_CREATED");
    $self->barrier_create("DLM_CHECKED");
    $self->barrier_create("OCFS2_MKFS_DONE");
    $self->barrier_create("OCFS2_GROUP_ALTERED");
    $self->barrier_create("OCFS2_DATA_COPIED");
    $self->barrier_create("OCFS2_MD5_CHECKED");
    $self->barrier_create("BEFORE_FENCING");
    $self->barrier_create("FENCING_DONE");
    $self->barrier_create("LOGS_CHECKED");
    $self->barrier_create("CLVM_INIT");
    $self->barrier_create("CLVM_RESOURCE_CREATED");
    $self->barrier_create("CLVM_PV_VG_LV_CREATED");
    $self->barrier_create("CLVM_VG_RESOURCE_CREATED");
    $self->barrier_create("CLVM_RW_CHECKED");
    $self->barrier_create("CLVM_MD5SUM");
    $self->barrier_create("PACEMAKER_CTS_INSTALLED");
    $self->barrier_create("PACEMAKER_CTS_FINISHED");
}

sub test_flags {
    return {fatal => 1};
}

1;
