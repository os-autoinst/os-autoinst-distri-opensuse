# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup of barriers for 2-host IPSec multimachine tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use lockapi;

sub run {
    my ($self) = @_;
    barrier_destroy('IPSEC_TUNNEL_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_SET_MTU_DONE');
    barrier_destroy('IPSEC_TUNNEL_MODE_CHECK_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_CHECK_DONE');
    barrier_destroy('IPSEC_TESTS_DONE');
}

sub test_flags {
    my ($self) = @_;
    return {fatal => 1};
}

1;
