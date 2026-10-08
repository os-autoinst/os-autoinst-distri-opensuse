# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup of all barriers for IPSec multimachine tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use utils;

sub run {
    my ($self) = @_;
    barrier_destroy('IPSEC_IP_SETUP_DONE');
    barrier_destroy('IPSEC_ROUTE_SETUP_DONE');
    barrier_destroy('IPSEC_ROUTE_SETUP_CHECK_DONE');
    barrier_destroy('IPSEC_TUNNEL_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_SET_MTU_DONE');
    barrier_destroy('IPSEC_TUNNEL_MODE_CHECK_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_CHECK_DONE');
    barrier_destroy('L2TP_SETUP_DONE');
    barrier_destroy('L2TP_TESTS_DONE');
}

sub test_flags {
    my ($self) = @_;
    return {fatal => 1};
}

1;
