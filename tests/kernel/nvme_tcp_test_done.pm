# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Tell the NVMe/TCP target of the topology that the test is done
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;

sub run {
    barrier_wait({name => 'NVME_TEST_DONE', check_dead_job => 1});
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Wait for the barrier C<NVME_TEST_DONE>, so that C<kernel/nvme_tcp_target>
removes the target. Schedule it after the last module that uses the
target.

=cut
