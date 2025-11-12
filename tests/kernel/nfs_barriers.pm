# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialization of barriers for NFS multimachine setup
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use lockapi;
use utils;

sub run {
    my $nodes = get_required_var("MULTIMACHINE_NODES");
    record_info("#barriers", $nodes);
    barrier_create("NFS_BEFORE_TEST_DONE", $nodes);
    barrier_create("NFS_SERVER_ENABLED", $nodes);
    barrier_create("NFS_CLIENT_ENABLED", $nodes);
    barrier_create("NFS_SERVER_CHECK", $nodes);
    barrier_create("NFS_STRESS_NG_START", $nodes);
    barrier_create("NFS_STRESS_NG_END", $nodes);
    barrier_create("NFS_NFSTEST_START", $nodes);
    barrier_create("NFS_NFSTEST_END", $nodes);
    if (check_var('KDUMP_OVER_NFS', '1')) {
        barrier_create("KDUMP_WICKED_TEMP", $nodes);
        barrier_create("KDUMP_MULTIMACHINE", $nodes);
    }
    record_info("barriers initialized");
}

sub test_flags {
    return {fatal => 1};
}

1;
