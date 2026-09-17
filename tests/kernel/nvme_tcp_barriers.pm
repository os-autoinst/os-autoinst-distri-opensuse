# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Initialization of barriers for NVMe-over-TCP 2-host baremetal setup
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use utils;

sub run {
    my $nodes = get_required_var("MULTIMACHINE_NODES");
    record_info("#barriers", $nodes);
    barrier_create("NVME_TARGET_READY", $nodes);
    barrier_create("NVME_INITIATOR_CONNECTED", $nodes);
    barrier_create("NVME_TEST_DONE", $nodes);
    record_info("barriers initialized");
}

sub test_flags {
    return {fatal => 1};
}

1;
