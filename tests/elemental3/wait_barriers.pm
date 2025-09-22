# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for master to initialize the mutexes/barriers.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;

sub run {
    mutex_wait('barriers_ready');
    barrier_wait('BARRIER_K8S_VALIDATION');
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
