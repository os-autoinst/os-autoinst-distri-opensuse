# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>,

use base 'opensusebasetest';
use testapi;
use lockapi;


sub run {
    barrier_create('IBTEST_SETUP', 2);
    barrier_create('IBTEST_BEGIN', 2);
    barrier_create('IBTEST_DONE', 2);
}

1;
