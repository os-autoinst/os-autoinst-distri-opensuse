# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initialization of barriers for IPSec multimachine tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest', -signatures;
use testapi;
use lockapi;
use utils;

sub run ($self) {
    # Get number of nodes
    my $nodes = get_required_var('IPSEC_NODES');
    record_info("#barriers", $nodes);
    barrier_create('IPSEC_IP_SETUP_DONE', $nodes);
    barrier_create('IPSEC_ROUTE_SETUP_DONE', $nodes);
    barrier_create('IPSEC_ROUTE_SETUP_CHECK_DONE', $nodes);
    barrier_create('IPSEC_TUNNEL_MODE_SETUP_DONE', $nodes);
    barrier_create('IPSEC_SET_MTU_DONE', $nodes);
    barrier_create('IPSEC_TUNNEL_MODE_CHECK_DONE', $nodes);
    barrier_create('IPSEC_TRANSPORT_MODE_SETUP_DONE', $nodes);
    barrier_create('IPSEC_TRANSPORT_MODE_CHECK_DONE', $nodes);
    record_info('barriers initialized', $nodes);
}

sub test_flags ($self) {
    return {fatal => 1};
}

1;
