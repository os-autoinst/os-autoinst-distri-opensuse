# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;


sub run {
    barrier_create('IBTEST_SETUP', 2);
    barrier_create('IBTEST_BEGIN', 2);
    barrier_create('IBTEST_DONE', 2);
}

1;

=head1 Description

Test module to create the barriers used for synchronizing the InfiniBand
master and slave test setup (ibtests_prepare / ibtests).

