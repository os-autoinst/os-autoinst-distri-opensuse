# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait until the NVMe/TCP target of the topology is ready
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;

sub run {
    # stop the VM while it waits, so that a boot menu does not time out
    freeze_vm;
    barrier_wait({name => 'NVME_TARGET_READY', check_dead_job => 1});
    resume_vm;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Wait for the barrier C<NVME_TARGET_READY> of C<kernel/nvme_tcp_target>.
Use it in a job that boots from the target, for example an installation,
before the boot. The VM is stopped while the job waits.

Run C<kernel/multimachine_barriers> first, with the barriers
C<NVME_TARGET_READY> and C<NVME_TEST_DONE>.

=cut
