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
    barrier_create("NFS_SERVER_ENABLED", $nodes);
    barrier_create("NFS_CLIENT_ENABLED", $nodes);
    barrier_create("NFS_SERVER_CHECK", $nodes);
    barrier_create("NFS_CLIENT_ACTIONS", $nodes);
    barrier_create("NFS_SERVER_ACTIONS", $nodes);
    record_info("barriers initialized");
}

sub test_flags {
    return {fatal => 1};
}

1;
