# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Server-side wait point until client completes LTP flow
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi 'barrier_wait';

sub run {
    record_info('LTP wait', 'Waiting on barrier NFS_LTP_END');
    barrier_wait('NFS_LTP_END');
}

sub test_flags {
    return {fatal => 1};
}

1;
