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
    my $barrier = get_required_var('LTP_DONE_BARRIER');
    record_info('LTP wait', "Waiting on barrier $barrier");
    barrier_wait($barrier);
}

sub test_flags {
    return {fatal => 1};
}

1;
