# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialization of barriers for 2-host IPSec multimachine tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest', -signatures;
use testapi;
use lockapi;

sub run ($self) {
    my $nodes = get_required_var('IPSEC_NODES');
    record_info('#barriers', $nodes);
    barrier_create('IPSEC_TUNNEL_MODE_SETUP_DONE', $nodes);
    barrier_create('IPSEC_SET_MTU_DONE', $nodes);
    barrier_create('IPSEC_TUNNEL_MODE_CHECK_DONE', $nodes);
    barrier_create('IPSEC_TRANSPORT_MODE_SETUP_DONE', $nodes);
    barrier_create('IPSEC_TRANSPORT_MODE_CHECK_DONE', $nodes);
    barrier_create('IPSEC_TESTS_DONE', $nodes);
    record_info('2-host barriers initialized', $nodes);
}

sub test_flags ($self) {
    return {fatal => 1};
}

1;
